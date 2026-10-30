import Combine
import SwiftUI
import WatchKit

struct MedicationListView: View {
	@Environment(\.colorScheme) private var colorScheme
	@EnvironmentObject var sender: WCSender
	@State private var isLoading = true
	@State private var now = Date()

	private let eligibilityTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

	var body: some View {
		NavigationStack {
			if isLoading {
				VStack {
					ProgressView()
					Text("Loading medications...")
						.font(.caption)
						.foregroundColor(.secondary)
				}
			} else if let message = sender.loadErrorMessage, !sender.hasLoadedMedications, sender.medications.isEmpty {
				ScrollView {
					VStack(spacing: 12) {
						Text("Medications Unavailable").font(.headline)
						Text(message).font(.caption).multilineTextAlignment(.center)
						Button("Refresh") { Task { await loadMedications() } }
					}
					.padding()
				}
			} else if sender.medications.isEmpty {
				VStack(spacing: 12) {
					Image(systemName: "pills")
						.font(.title2)
						.foregroundColor(.secondary)
					Text("No medications")
						.font(.headline)
					Text("Add medications in the iPhone app")
						.font(.caption)
						.foregroundColor(.secondary)
						.multilineTextAlignment(.center)

					Button("Refresh") {
						Task {
							await loadMedications()
						}
					}
					.font(.caption)
					.padding(.horizontal, 16)
					.padding(.vertical, 8)
					.background(Color.accent)
					.foregroundStyle(colorScheme == .dark ? .black : .white)
					.cornerRadius(8)
				}
				.padding()
			} else if sender.medications.count == 1 {
				// Single medication - show simplified view with quick actions
				if let medication = sender.medications.first {
					ScrollView {
					VStack(spacing: 16) {
						if let message = sender.loadErrorMessage {
							Text("Showing the last received list. \(message)").font(.caption)
						}
						if let message = sender.actionMessage {
							Text(message).font(.caption).fixedSize(horizontal: false, vertical: true)
						}
						NavigationLink(destination: MedicationDetailView(medication: medication)) {
							VStack(spacing: 8) {
								Text(medication.displayName)
									.font(.title3)
									.fontWeight(.semibold)
									.multilineTextAlignment(.center)

								HStack {
									Text("Quantity: \(medication.quantity.formatted(.number.precision(.fractionLength(0...2))))")
										.font(.caption)
										.foregroundColor(.secondary)

									if let prescribedDoseAmount = medication.prescribedDoseAmount,
									   let prescribedUnit = medication.prescribedUnit
									{
										Text(verbatim: "| " + WatchMedication.localizedAmount(prescribedDoseAmount, unit: prescribedUnit))
											.font(.caption)
											.foregroundColor(.secondary)
									}
								}

								statusRow(for: medication, at: now)
							}
							.padding()
							.background(Color.gray.opacity(0.2))
							.cornerRadius(12)
						}

						// Quick log button for single medication
						Button(action: {
							logQuickDoseForMedication(medication)
						}) {
							HStack {
									Image(systemName: "plus.circle.fill")
									Text("Quick Log")
									if let amount = medication.prescribedDoseAmount,
									   let unit = medication.prescribedUnit
									{
										Text(verbatim: "(" + WatchMedication.localizedAmount(amount, unit: unit) + ")")
											.font(.caption)
									}
							}
							.frame(maxWidth: .infinity)
							.padding()
							.background(Color.accent)
							.foregroundStyle(colorScheme == .dark ? .black : .white)
							.cornerRadius(12)
						}
						.buttonStyle(.plain)
						.accessibilityLabel(medication.quickLogAccessibilityLabel)
						.disabled(sender.isSendingAction)

						Spacer()
					}
					.padding()
					.refreshable {
						await loadMedications()
					}
					}
				} else {
					Text("Unable to load medication")
						.foregroundColor(.secondary)
				}
			} else {
				// Multiple medications - show list with quick log buttons
				List {
					if let message = sender.loadErrorMessage {
						Text("Showing the last received list. \(message)").font(.caption)
					}
					if let message = sender.actionMessage {
						Text(message).font(.caption)
					}
					ForEach(sender.medications) { medication in
						MedicationRowView(medication: medication, now: now)
					}
				}
				.refreshable {
					await loadMedications()
				}
			}
		}
		.navigationTitle("Medications")
		.onAppear {
			Task {
				await loadMedications()
			}
		}
		.onReceive(eligibilityTimer) { now = $0 }
	}

	private func logQuickDoseForMedication(_ medication: WatchMedication) {
		let doseAmount = medication.prescribedDoseAmount ?? 1.0
		let doseUnit = medication.prescribedUnit ?? "dose"

		let eventData: [String: Any] = [
			"medicationId": medication.id.uuidString,
			"doseAmount": doseAmount,
			"doseUnit": doseUnit,
			"quantityConsumed": doseAmount,
		]

		Task { await sender.sendAction(key: "logDose", value: eventData) }
	}

	@ViewBuilder
	private func statusRow(for medication: WatchMedication, at date: Date) -> some View {
		let canTakeNow = medication.canTake(at: date)

		if medication.nextDoseDate == nil, !canTakeNow, let reason = medication.statusMessage {
			Text(reason)
				.font(.caption2)
				.foregroundColor(.orange)
				.fixedSize(horizontal: false, vertical: true)
		} else if medication.lowStock || medication.refillSoon || !canTakeNow {
			HStack(spacing: 4) {
				if medication.lowStock {
					Label("Low", systemImage: "exclamationmark.triangle.fill")
						.foregroundColor(.orange)
				} else if !canTakeNow {
					Label(nextDoseLabel(for: medication, relativeTo: date), systemImage: "clock.fill")
						.foregroundColor(.orange)
				} else if medication.refillSoon {
					Label("Refill soon", systemImage: "shippingbox.fill")
						.foregroundColor(.yellow)
				}
			}
			.font(.caption2)
		} else if let statusMessage = medication.statusMessage {
			Text(statusMessage)
				.font(.caption2)
				.foregroundColor(.secondary)
				.lineLimit(2)
		}
	}

	private func nextDoseLabel(for medication: WatchMedication, relativeTo date: Date) -> String {
		guard let nextDoseDate = medication.nextDoseDate else {
			return String(localized: "Review saved limits")
		}

		let formatter = RelativeDateTimeFormatter()
		formatter.unitsStyle = .short
		return formatter.localizedString(for: nextDoseDate, relativeTo: date)
	}

	private func loadMedications() async {
		isLoading = true
		sender.hasLoadedMedications = false
		sender.loadErrorMessage = nil
		guard sender.isConnected else {
			sender.loadErrorMessage = String(localized: "Open AsNeeded on your nearby iPhone, then refresh.")
			isLoading = false
			return
		}
		sender.sendMessage(key: "getMedications", value: "request")

		// Wait for response with timeout
		for _ in 0 ..< 30 { // 3 second timeout
			try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
			if sender.hasLoadedMedications || sender.loadErrorMessage != nil {
				break
			}
		}

		if !sender.hasLoadedMedications, sender.loadErrorMessage == nil {
			sender.loadErrorMessage = String(localized: "iPhone hasn’t responded. Open AsNeeded there, then refresh.")
		}
		isLoading = false
	}
}

struct MedicationRowView: View {
	let medication: WatchMedication
	let now: Date
	@EnvironmentObject var sender: WCSender

	init(medication: WatchMedication, now: Date) {
		self.medication = medication
		self.now = now
	}

	var body: some View {
		HStack {
			NavigationLink(destination: MedicationDetailView(medication: medication)) {
			VStack(alignment: .leading, spacing: 4) {
				Text(medication.displayName)
					.font(.headline)
					.fixedSize(horizontal: false, vertical: true)

				HStack {
					Text("Quantity: \(medication.quantity.formatted(.number.precision(.fractionLength(0...2))))")
						.font(.caption)
						.foregroundColor(.secondary)

					Spacer()

					if let prescribedDoseAmount = medication.prescribedDoseAmount,
					   let prescribedUnit = medication.prescribedUnit
					{
						Text(WatchMedication.localizedAmount(prescribedDoseAmount, unit: prescribedUnit))
							.font(.caption)
							.foregroundColor(.secondary)
					}
				}

				statusRow(for: medication, at: now)
			}
			}

			Spacer()

			// Quick log button
			Button(action: logQuickDose) {
				Image(systemName: "plus.circle.fill")
					.font(.title3)
					.foregroundColor(.accent)
					.frame(minWidth: 44, minHeight: 44)
			}
			.buttonStyle(.plain)
			.accessibilityLabel(medication.quickLogAccessibilityLabel)
			.disabled(sender.isSendingAction)
		}
		.padding(.vertical, 2)
	}

	private func logQuickDose() {
		let doseAmount = medication.prescribedDoseAmount ?? 1.0
		let doseUnit = medication.prescribedUnit ?? "dose"

		let eventData: [String: Any] = [
			"medicationId": medication.id.uuidString,
			"doseAmount": doseAmount,
			"doseUnit": doseUnit,
			"quantityConsumed": doseAmount,
		]

		Task { await sender.sendAction(key: "logDose", value: eventData) }
	}

	@ViewBuilder
	private func statusRow(for medication: WatchMedication, at date: Date) -> some View {
		let canTakeNow = medication.canTake(at: date)

		if medication.nextDoseDate == nil, !canTakeNow, let reason = medication.statusMessage {
			Text(reason)
				.font(.caption2)
				.foregroundColor(.orange)
				.fixedSize(horizontal: false, vertical: true)
		} else if medication.lowStock || medication.refillSoon || !canTakeNow {
			HStack(spacing: 4) {
				if medication.lowStock {
					Label("Low", systemImage: "exclamationmark.triangle.fill")
						.foregroundColor(.orange)
				} else if !canTakeNow {
					Label(nextDoseLabel(for: medication, relativeTo: date), systemImage: "clock.fill")
						.foregroundColor(.orange)
				} else if medication.refillSoon {
					Label("Refill soon", systemImage: "shippingbox.fill")
						.foregroundColor(.yellow)
				}
			}
			.font(.caption2)
		} else if let statusMessage = medication.statusMessage {
			Text(statusMessage)
				.font(.caption2)
				.foregroundColor(.secondary)
				.lineLimit(2)
		}
	}

	private func nextDoseLabel(for medication: WatchMedication, relativeTo date: Date) -> String {
		guard let nextDoseDate = medication.nextDoseDate else {
			return String(localized: "Review saved limits")
		}

		let formatter = RelativeDateTimeFormatter()
		formatter.unitsStyle = .short
		return formatter.localizedString(for: nextDoseDate, relativeTo: date)
	}
}

#if DEBUG
	#Preview {
		MedicationListView()
	}
#endif
