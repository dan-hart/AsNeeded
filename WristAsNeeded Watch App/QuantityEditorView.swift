import SwiftUI

struct QuantityEditorView: View {
    let medication: WatchMedication
    @Binding var quantity: Double
    @EnvironmentObject var sender: WCSender
    @Environment(\.dismiss) private var dismiss
    @State private var isUpdating = false
    
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
                        Text("\(medication.quantity, specifier: "%.0f")")
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
                        
                        HStack {
                            Button("-") {
                                if quantity > 0 {
                                    quantity -= 1
                                }
                            }
                            .font(.title2)
                            .frame(width: 40, height: 40)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(8)
                            
                            Spacer()
                            
                            Text("\(quantity, specifier: "%.0f")")
                                .font(.title)
                                .fontWeight(.semibold)
                                .frame(minWidth: 60)
                            
                            Spacer()
                            
                            Button("+") {
                                quantity += 1
                            }
                            .font(.title2)
                            .frame(width: 40, height: 40)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(8)
                        }
                        
                        // Quick adjustment buttons
                        HStack(spacing: 8) {
                            Button("+5") {
                                quantity += 5
                            }
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(8)
                            
                            Button("+10") {
                                quantity += 10
                            }
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(8)
                            
                            Spacer()
                            
                            Button("Reset") {
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
                    
                    // Update button
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
                                Text("Update Quantity")
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isUpdating || quantity == medication.quantity ? Color.gray : Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .disabled(isUpdating || quantity == medication.quantity)
                }
                .padding()
            }
            .navigationTitle("Update Quantity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func updateQuantity() {
        isUpdating = true
        
        let quantityData: [String: Any] = [
            "medicationId": medication.id.uuidString,
            "quantity": quantity
        ]
        
        sender.sendMessage(key: "updateQuantity", value: quantityData)
        
        // Provide haptic feedback
        WKInterfaceDevice.current().play(.success)
        
        // Dismiss after a short delay to show the loading state
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isUpdating = false
            dismiss()
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