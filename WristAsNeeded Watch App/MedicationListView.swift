import SwiftUI
import WatchKit

struct MedicationListView: View {
	@EnvironmentObject var sender: WCSender
	@State private var isLoading = true
	
	var body: some View {
		NavigationStack {
			if isLoading {
				VStack {
					ProgressView()
					Text("Loading medications...")
						.font(.caption)
						.foregroundColor(.secondary)
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
					.background(Color.accentColor)
					.foregroundColor(.white)
					.cornerRadius(8)
				}
				.padding()
			} else if sender.medications.count == 1 {
				// Single medication - show simplified view with quick actions
				let medication = sender.medications[0]
				VStack(spacing: 16) {
					NavigationLink(destination: MedicationDetailView(medication: medication)) {
						VStack(spacing: 8) {
							Text(medication.displayName)
								.font(.title3)
								.fontWeight(.semibold)
								.multilineTextAlignment(.center)
							
							HStack {
								Text("Qty: \(medication.quantity, specifier: "%.0f")")
									.font(.caption)
									.foregroundColor(.secondary)
								
								if let prescribedDoseAmount = medication.prescribedDoseAmount,
								   let prescribedUnit = medication.prescribedUnit {
									Text("| \(prescribedDoseAmount, specifier: "%.1f") \(prescribedUnit)")
										.font(.caption)
										.foregroundColor(.secondary)
								}
							}
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
							   let unit = medication.prescribedUnit {
								Text("(\(amount, specifier: "%.1f") \(unit))")
									.font(.caption)
							}
						}
						.frame(maxWidth: .infinity)
						.padding()
						.background(Color.green)
						.foregroundColor(.white)
						.cornerRadius(12)
					}
					.buttonStyle(.plain)
					
					Spacer()
				}
				.padding()
				.refreshable {
					await loadMedications()
				}
			} else {
				// Multiple medications - show list with quick log buttons
				List {
					ForEach(sender.medications) { medication in
						NavigationLink(destination: MedicationDetailView(medication: medication)) {
							MedicationRowView(medication: medication)
						}
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
	}
	
	private func logQuickDoseForMedication(_ medication: WatchMedication) {
		let doseAmount = medication.prescribedDoseAmount ?? 1.0
		let doseUnit = medication.prescribedUnit ?? "dose"
		
		let eventData: [String: Any] = [
			"medicationId": medication.id.uuidString,
			"doseAmount": doseAmount,
			"doseUnit": doseUnit,
			"quantityConsumed": doseAmount
		]
		
		sender.sendMessage(key: "logDose", value: eventData)
		
		// Provide subtle haptic feedback
		WKInterfaceDevice.current().play(.click)
	}
	
	private func loadMedications() async {
		isLoading = true
		sender.sendMessage(key: "getMedications", value: "request")
		
		// Wait for response with timeout
		for _ in 0..<30 { // 3 second timeout
			try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
			if !sender.medications.isEmpty {
				break
			}
		}
		
		isLoading = false
	}
}

struct MedicationRowView: View {
	let medication: WatchMedication
	@EnvironmentObject var sender: WCSender
	@State private var currentQuantity: Double
	
	init(medication: WatchMedication) {
		self.medication = medication
		self._currentQuantity = State(initialValue: medication.quantity)
	}
	
	var body: some View {
		HStack {
			VStack(alignment: .leading, spacing: 4) {
				Text(medication.displayName)
					.font(.headline)
					.lineLimit(2)
				
				HStack {
					Text("Qty: \(currentQuantity, specifier: "%.0f")")
						.font(.caption)
						.foregroundColor(.secondary)
					
					Spacer()
					
					if let prescribedDoseAmount = medication.prescribedDoseAmount,
					   let prescribedUnit = medication.prescribedUnit {
						Text("\(prescribedDoseAmount, specifier: "%.1f") \(prescribedUnit)")
							.font(.caption)
							.foregroundColor(.secondary)
					}
				}
			}
			
			Spacer()
			
			// Quick log button
			Button(action: logQuickDose) {
				Image(systemName: "plus.circle.fill")
					.font(.title3)
					.foregroundColor(.green)
			}
			.buttonStyle(.plain)
			.frame(width: 30, height: 30)
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
			"quantityConsumed": doseAmount
		]
		
		sender.sendMessage(key: "logDose", value: eventData)
		
		// Update local quantity immediately for better UX
		if currentQuantity > 0 {
			currentQuantity = max(0, currentQuantity - doseAmount)
		}
		
		// Provide subtle haptic feedback
		WKInterfaceDevice.current().play(.click)
	}
}

#if DEBUG
#Preview {
	MedicationListView()
}
#endif