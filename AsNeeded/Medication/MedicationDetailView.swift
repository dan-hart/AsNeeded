// MedicationDetailView.swift
// SwiftUI view for showing details of a medication, including delete option.

import SwiftUI
import Boutique
import ANModelKit

struct MedicationDetailView: View {
    let medication: ANMedicationConcept
    var store = Medication.store
    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteConfirm = false
    @State private var showLogDose = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(medication.displayName)
                    .font(.largeTitle.weight(.bold))
                
                if let quantity = medication.quantity {
                    Text("Quantity: \(quantity)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                if let lastRefill = medication.lastRefillDate {
                    Text("Last Refill: \(lastRefill, format: .dateTime.year().month().day())")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                if let nextRefill = medication.nextRefillDate {
                    Text("Next Refill: \(nextRefill, format: .dateTime.year().month().day())")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Button("Log Dose") {
                    showLogDose = true
                }
                .buttonStyle(.borderedProminent)
                Spacer()
            }
            .padding()
        }
        .navigationTitle("Details")
        .toolbar {
            ToolbarItem(placement: .destructiveAction) {
                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
        .alert("Are you sure you want to delete this medication?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                Task {
                    try? await store.remove(medication)
                    dismiss()
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showLogDose) {
            LogDoseView(medication: medication) { event in
                Task {
                    try? await ANEventConcept.store.insert(event)
                }
            }
        }
    }
}

#Preview {
    MedicationDetailView(medication: ANMedicationConcept(
        clinicalName: "Albuterol Inhaler",
        nickname: "Rescue Inhaler"
    ))
}

#Preview("Medication with Long History") {
    MedicationDetailView(medication: ANMedicationConcept(
        clinicalName: "Metformin",
        nickname: "Diabetes Med"
    ))
}

#Preview("Medication with Refill Info") {
    MedicationDetailView(medication: ANMedicationConcept(
        clinicalName: "Lisinopril",
        nickname: "Blood Pressure",
        quantity: 30,
        lastRefillDate: Date(timeIntervalSinceNow: -86400 * 10),
        nextRefillDate: Date(timeIntervalSinceNow: 86400 * 20)
    ))
}
