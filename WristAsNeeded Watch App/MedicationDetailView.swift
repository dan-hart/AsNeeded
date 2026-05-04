import Combine
import SwiftUI
import WatchKit

struct MedicationDetailView: View {
    let medication: WatchMedication
    @EnvironmentObject var sender: WCSender
    @State private var doseAmount: Double
    @State private var showingDoseLogger = false
    @State private var showingQuantityEditor = false
    @State private var newQuantity: Double
    @State private var currentQuantity: Double
    @State private var now = Date()

    private let eligibilityTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    init(medication: WatchMedication) {
        self.medication = medication
        _doseAmount = State(initialValue: medication.prescribedDoseAmount ?? 1.0)
        _newQuantity = State(initialValue: medication.quantity)
        _currentQuantity = State(initialValue: medication.quantity)
    }

    var body: some View {
        let canTakeNow = medication.canTake(at: now)

        ScrollView {
            VStack(spacing: 16) {
                // Medication Info
                VStack(alignment: .leading, spacing: 8) {
                    Text(medication.displayName)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .multilineTextAlignment(.center)

                    HStack {
                        Text("Quantity:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(currentQuantity, specifier: "%.0f")")
                            .font(.caption)
                            .fontWeight(.medium)
                        Spacer()
                        Button("Edit") {
                            showingQuantityEditor = true
                        }
                        .font(.caption2)
                        .buttonStyle(.borderless)
                    }

                    if let prescribedDoseAmount = medication.prescribedDoseAmount,
                       let prescribedUnit = medication.prescribedUnit
                    {
                        HStack {
                            Text("Prescribed:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(prescribedDoseAmount, specifier: "%.1f") \(prescribedUnit)")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                    }

                    if medication.lowStock || medication.refillSoon || !canTakeNow {
                        statusBadge
                    } else if let statusMessage = medication.statusMessage {
                        Text(statusMessage)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.2))
                .cornerRadius(12)

                // Quick Actions
                VStack(spacing: 12) {
                    Button(action: {
                        showingDoseLogger = true
                    }) {
                        HStack {
                            Image(systemName: canTakeNow ? "plus.circle.fill" : "clock.fill")
                            Text(canTakeNow ? "Log Dose" : nextDoseLabel)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(canTakeNow ? Color.accent : Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                    .disabled(!canTakeNow)

                    Button(action: {
                        logQuickDose()
                    }) {
                        HStack {
                            if canTakeNow {
                                Image(systemName: "bolt.fill")
                                Text("Quick Log")
                                if let amount = medication.prescribedDoseAmount,
                                   let unit = medication.prescribedUnit
                                {
                                    Text("(\(amount, specifier: "%.1f") \(unit))")
                                        .font(.caption)
                                }
                            } else {
                                Image(systemName: "clock.fill")
                                Text(nextDoseLabel)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(canTakeNow ? Color.green : Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                    .disabled(!canTakeNow)
                }
            }
            .padding()
        }
        .navigationTitle("Details")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingDoseLogger) {
            DoseLoggerView(medication: medication, doseAmount: $doseAmount)
                .onDisappear {
                    // Update quantity after logging dose
                    if currentQuantity > 0 {
                        currentQuantity = max(0, currentQuantity - doseAmount)
                    }
                }
        }
        .sheet(isPresented: $showingQuantityEditor) {
            QuantityEditorView(medication: medication, quantity: $newQuantity)
        }
        .onReceive(eligibilityTimer) { now = $0 }
    }

    private func logQuickDose() {
        guard medication.canTake(at: Date()) else {
            WKInterfaceDevice.current().play(.failure)
            return
        }

        let doseAmount = medication.prescribedDoseAmount ?? 1.0
        let doseUnit = medication.prescribedUnit ?? "dose"

        let eventData: [String: Any] = [
            "medicationId": medication.id.uuidString,
            "doseAmount": doseAmount,
            "doseUnit": doseUnit,
            "quantityConsumed": doseAmount,
        ]

        sender.sendMessage(key: "logDose", value: eventData)

        // Update local quantity immediately for better UX
        if currentQuantity > 0 {
            currentQuantity = max(0, currentQuantity - doseAmount)
        }

        // Provide subtle haptic feedback
        WKInterfaceDevice.current().play(.click)
    }

    private var statusBadge: some View {
        HStack(spacing: 6) {
            if medication.lowStock {
                Label("Low stock", systemImage: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
            } else if !medication.canTake(at: now) {
                Label(nextDoseLabel, systemImage: "clock.fill")
                    .foregroundColor(.orange)
            } else if medication.refillSoon {
                Label("Refill soon", systemImage: "shippingbox.fill")
                    .foregroundColor(.yellow)
            }
        }
        .font(.caption2)
    }

    private var nextDoseLabel: String {
        guard let nextDoseDate = medication.nextDoseDate else {
            return "Not ready"
        }

        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: nextDoseDate, relativeTo: now)
    }
}

#if DEBUG
    #Preview {
        NavigationStack {
            MedicationDetailView(
                medication: WatchMedication(
                    id: UUID(),
                    displayName: "Ibuprofen",
                    quantity: 24,
                    prescribedDoseAmount: 2.0,
                    prescribedUnit: "tablet"
                )
            )
        }
    }
#endif
