import SwiftUI

struct DoseLoggerView: View {
    let medication: WatchMedication
    @Binding var doseAmount: Double
    @EnvironmentObject var sender: WCSender
    @Environment(\.dismiss) private var dismiss
    @State private var selectedUnit: String
    @State private var isLogging = false
    
    private let availableUnits = ["tablet", "capsule", "mg", "mL", "puff", "dose", "unit"]
    
    init(medication: WatchMedication, doseAmount: Binding<Double>) {
        self.medication = medication
        self._doseAmount = doseAmount
        self._selectedUnit = State(initialValue: medication.prescribedUnit ?? "dose")
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Medication name
                    Text(medication.displayName)
                        .font(.headline)
                        .multilineTextAlignment(.center)
                        .padding(.bottom, 8)
                    
                    // Dose amount selector
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Amount")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Button("-") {
                                if doseAmount > 0.25 {
                                    doseAmount -= 0.25
                                }
                            }
                            .font(.title2)
                            .frame(width: 40, height: 40)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(8)
                            
                            Spacer()
                            
                            Text("\(doseAmount, specifier: doseAmount.truncatingRemainder(dividingBy: 1) == 0 ? "%.0f" : "%.2f")")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .frame(minWidth: 60)
                            
                            Spacer()
                            
                            Button("+") {
                                doseAmount += 0.25
                            }
                            .font(.title2)
                            .frame(width: 40, height: 40)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(8)
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(12)
                    
                    // Unit selector
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Unit")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Picker("Unit", selection: $selectedUnit) {
                            ForEach(availableUnits, id: \.self) { unit in
                                Text(unit).tag(unit)
                            }
                        }
                        .pickerStyle(WheelPickerStyle())
                        .frame(height: 80)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(12)
                    
                    // Log button
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
                                Text("Log Dose")
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isLogging ? Color.gray : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .disabled(isLogging)
                }
                .padding()
            }
            .navigationTitle("Log Dose")
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
    
    private func logDose() {
        isLogging = true
        
        let eventData: [String: Any] = [
            "medicationId": medication.id.uuidString,
            "doseAmount": doseAmount,
            "doseUnit": selectedUnit,
            "quantityConsumed": doseAmount
        ]
        
        sender.sendMessage(key: "logDose", value: eventData)
        
        // Provide haptic feedback
        WKInterfaceDevice.current().play(.success)
        
        // Dismiss after a short delay to show the loading state
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isLogging = false
            dismiss()
        }
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