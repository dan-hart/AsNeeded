import Combine
import SwiftUI
import WatchKit

struct DoseLoggerView: View {
	@Environment(\.colorScheme) private var colorScheme
	private let initialMedication: WatchMedication
	@Binding var doseAmount: Double
	@EnvironmentObject var sender: WCSender
	@Environment(\.dismiss) private var dismiss
	@State private var selectedUnit: String
	@State private var isLogging = false
	@State private var eventID = UUID()
	@State private var loggedAt: Date?
	@State private var isQueued = false
	@State private var now = Date()

	private let availableUnits = ["tablet", "capsule", "mg", "mL", "puff", "dose", "unit"]
	private let eligibilityTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

	init(medication: WatchMedication, doseAmount: Binding<Double>) {
		initialMedication = medication
		_doseAmount = doseAmount
		// Use prescribed unit from medication
		_selectedUnit = State(initialValue: medication.prescribedUnit ?? "dose")
	}

	private var medication: WatchMedication {
		sender.medications.first { $0.id == initialMedication.id } ?? initialMedication
	}

	var body: some View {
		let canTakeNow = medication.canTake(at: now)

		NavigationStack {
			ScrollView {
				VStack(spacing: 16) {
					// Medication name
					Text(medication.displayName)
						.font(.headline)
						.multilineTextAlignment(.center)
						.padding(.bottom, 8)

					if !canTakeNow {
						Label(medication.nextDoseDate == nil ? medication.statusMessage ?? String(localized: "Review saved limits") : nextDoseLabel, systemImage: "clock.fill")
							.font(.caption)
							.foregroundColor(.orange)
					} else if medication.lowStock || medication.refillSoon {
						Label(medication.lowStock ? String(localized: "Low stock") : String(localized: "Refill soon"), systemImage: medication.lowStock ? "exclamationmark.triangle.fill" : "shippingbox.fill")
							.font(.caption)
							.foregroundColor(medication.lowStock ? .orange : .yellow)
					}

					// Dose amount selector
					VStack(alignment: .leading, spacing: 8) {
						HStack {
							Text("Amount")
								.font(.caption)
								.foregroundColor(.secondary)
							Spacer()
							if let prescribedAmount = medication.prescribedDoseAmount {
								Text("Prescribed: \(prescribedAmount, specifier: "%.1f")")
									.font(.caption2)
									.foregroundColor(.secondary)
							}
						}

						Text(doseAmount.formatted(.number.precision(.fractionLength(0...3))))
							.font(.title2)
							.fontWeight(.semibold)
							.frame(maxWidth: .infinity)
						HStack {
							Button {
								doseAmount = max(0.25, doseAmount - 0.25)
								WKInterfaceDevice.current().play(.click)
							} label: {
								Image(systemName: "minus")
									.frame(minWidth: 44, minHeight: 44)
							}
							.accessibilityLabel("Decrease amount")
							.font(.title2)
							.background(Color.gray.opacity(0.2))
							.cornerRadius(8)

							Spacer()

							Button {
								doseAmount += 0.25
								WKInterfaceDevice.current().play(.click)
							} label: {
								Image(systemName: "plus")
									.frame(minWidth: 44, minHeight: 44)
							}
							.accessibilityLabel("Increase amount")
							.font(.title2)
							.background(Color.gray.opacity(0.2))
							.cornerRadius(8)
						}
					}
					.padding()
					.background(Color.gray.opacity(0.2))
					.cornerRadius(12)
					.disabled(isLogging || isQueued)

					// Unit selector - show only if no prescribed unit
					Group {
						if medication.prescribedUnit == nil {
							VStack(alignment: .leading, spacing: 8) {
								Text("Unit")
									.font(.caption)
									.foregroundColor(.secondary)

								Picker("Unit", selection: $selectedUnit) {
									ForEach(availableUnits, id: \.self) { unit in
										Text(WatchMedication.localizedUnit(unit)).tag(unit)
									}
								}
								.pickerStyle(WheelPickerStyle())
								.frame(height: 80)
							}
						} else {
							// Show prescribed unit as read-only
							HStack {
								Text("Unit")
									.font(.caption)
									.foregroundColor(.secondary)
								Spacer()
								Text(WatchMedication.localizedUnit(selectedUnit))
									.font(.headline)
							}
						}
					}
					.padding()
					.background(Color.gray.opacity(0.2))
					.cornerRadius(12)
					.disabled(isLogging || isQueued)

					// Log button
					if let message = sender.actionMessage {
						Text(message)
							.font(.caption)
							.fixedSize(horizontal: false, vertical: true)
					}
					Button(action: logDose) {
						if isLogging {
							HStack {
								ProgressView()
									.scaleEffect(0.8)
								Text("Logging...")
							}
						} else {
							HStack {
								Image(systemName: "checkmark.circle.fill")
								Text(isQueued ? String(localized: "Waiting to Sync") : String(localized: "Log Dose"))
							}
						}
					}
					.frame(maxWidth: .infinity)
					.padding()
					.background(isLogging ? Color.gray : Color.accent)
					.foregroundStyle(colorScheme == .dark ? .black : .white)
					.cornerRadius(12)
					.disabled(isLogging || isQueued)
				}
				.padding()
			}
			.navigationTitle("Log Dose")
			.navigationBarTitleDisplayMode(.inline)
			.toolbar {
				ToolbarItem(placement: .cancellationAction) {
						Button(isQueued ? String(localized: "Close") : String(localized: "Cancel")) {
						dismiss()
					}
					.disabled(isLogging)
				}
			}
		}
		.onAppear { sender.actionMessage = nil }
		.onReceive(eligibilityTimer) { now = $0 }
	}

	private func logDose() {
		guard !isLogging else { return }
		isLogging = true

		if loggedAt == nil { loggedAt = Date() }
		let eventData: [String: Any] = [
			"eventID": eventID.uuidString,
			"date": loggedAt ?? Date(),
			"medicationId": medication.id.uuidString,
			"doseAmount": doseAmount,
			"doseUnit": selectedUnit,
			"quantityConsumed": doseAmount,
		]

		Task {
			let outcome = await sender.sendAction(key: "logDose", value: eventData)
			isLogging = false
			switch outcome {
			case .saved:
				WKInterfaceDevice.current().play(.success)
				dismiss()
			case .queued:
				isQueued = true
			case .failed:
				break
			}
		}
	}

	private var nextDoseLabel: String {
		guard let nextDoseDate = medication.nextDoseDate else {
			return String(localized: "This medication is not ready yet.")
		}

		let formatter = RelativeDateTimeFormatter()
		formatter.unitsStyle = .short
		return String(localized: "Saved interval ends \(formatter.localizedString(for: nextDoseDate, relativeTo: now))")
	}
}

#if DEBUG
	#Preview {
		DoseLoggerView(
			medication: WatchMedication(
				id: UUID(),
				displayName: "Ibuprofen",
				quantity: 24,
				prescribedDoseAmount: 2.0,
				prescribedUnit: "tablet"
			),
			doseAmount: .constant(2.0)
		)
	}
#endif
