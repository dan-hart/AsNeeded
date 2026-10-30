import SwiftUI
import WatchKit

struct QuantityEditorView: View {
	@Environment(\.colorScheme) private var colorScheme
    let medication: WatchMedication
    @Binding var quantity: Double
    @EnvironmentObject var sender: WCSender
    @Environment(\.dismiss) private var dismiss
    @State private var isUpdating = false
	@State private var isQueued = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Medication name
                    Text(medication.displayName)
                        .font(.headline)
                        .multilineTextAlignment(.center)
                        .padding(.bottom, 8)

                    // Current quantity display
                    VStack(spacing: 8) {
                        Text("Current Quantity")
                            .font(.caption)
                            .foregroundColor(.secondary)
						Text(WatchMedication.localizedAmount(medication.quantity, unit: medication.prescribedUnit ?? "units"))
                            .font(.title2)
                            .fontWeight(.semibold)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(12)

                    // New quantity selector
                    VStack(alignment: .leading, spacing: 8) {
                        Text("New Quantity")
                            .font(.caption)
                            .foregroundColor(.secondary)

						Text(quantity.formatted(.number.precision(.fractionLength(0...3))))
							.font(.title2)
							.fontWeight(.semibold)
							.frame(maxWidth: .infinity)
						HStack {
							Button {
								quantity = max(0, quantity - 1)
							} label: {
								Image(systemName: "minus").frame(minWidth: 44, minHeight: 44)
							}
							.accessibilityLabel("Decrease quantity")
                            .font(.title2)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(8)

                            Spacer()

							Button {
                                quantity += 1
							} label: {
								Image(systemName: "plus").frame(minWidth: 44, minHeight: 44)
                            }
							.accessibilityLabel("Increase quantity")
                            .font(.title2)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(8)
                        }

                        // Quick adjustment buttons
						VStack(spacing: 8) {
							Button("Add 5") {
                                quantity += 5
                            }
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(8)

							Button("Add 10") {
                                quantity += 10
                            }
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(8)


							Button("Reset Changes") {
                                quantity = medication.quantity
                            }
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.red.opacity(0.2))
                            .foregroundColor(.red)
                            .cornerRadius(8)
                        }
                        .padding(.top, 4)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(12)
					.disabled(isUpdating || isQueued)

                    // Update button
					if let message = sender.actionMessage {
						Text(message).font(.caption).fixedSize(horizontal: false, vertical: true)
					}
                    Button(action: updateQuantity) {
                        if isUpdating {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Updating...")
                            }
                        } else {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
								Text(isQueued ? String(localized: "Waiting to Sync") : String(localized: "Save Quantity"))
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
					.background(isUpdating || isQueued || quantity == medication.quantity ? Color.gray : Color.accent)
                    .foregroundStyle(colorScheme == .dark ? .black : .white)
                    .cornerRadius(12)
					.disabled(isUpdating || isQueued || !quantity.isFinite || quantity < 0 || quantity == medication.quantity)
                }
                .padding()
            }
            .navigationTitle("Update Quantity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
					Button(isQueued ? String(localized: "Close") : String(localized: "Cancel")) {
                        dismiss()
                    }
					.disabled(isUpdating)
                }
            }
        }
		.onAppear { sender.actionMessage = nil }
    }

    private func updateQuantity() {
		guard quantity.isFinite, quantity >= 0 else { return }
        isUpdating = true

        let quantityData: [String: Any] = [
            "medicationId": medication.id.uuidString,
            "quantity": quantity,
        ]

		Task {
			let outcome = await sender.sendAction(key: "updateQuantity", value: quantityData)
            isUpdating = false
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
}

#if DEBUG
    #Preview {
        QuantityEditorView(
            medication: WatchMedication(
                id: UUID(),
                displayName: "Ibuprofen",
                quantity: 24,
                prescribedDoseAmount: 2.0,
                prescribedUnit: "tablet"
            ),
            quantity: .constant(24)
        )
    }
#endif
