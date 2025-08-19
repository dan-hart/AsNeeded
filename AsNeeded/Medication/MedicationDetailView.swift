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
        Form {
            Section("Medication Details") {
                HStack {
                    Text("Clinical Name")
                    Spacer()
                    Text(medication.clinicalName)
                        .foregroundStyle(.secondary)
                }
                
                HStack {
                    Text("Nickname")
                    Spacer()
                    Text(medication.nickname ?? "—")
                        .foregroundStyle(.secondary)
                }
                
                HStack {
                    Text("Quantity")
                    Spacer()
                    if let quantity = medication.quantity {
                        Text("\(quantity)")
                            .foregroundStyle(.secondary)
                    } else {
                        Text("—")
                            .foregroundStyle(.secondary)
                    }
                }
                
                HStack {
                    Text("Last Refill")
                    Spacer()
                    if let lastRefill = medication.lastRefillDate {
                        Text(lastRefill, format: .dateTime.year().month().day())
                            .foregroundStyle(.secondary)
                    } else {
                        Text("—")
                            .foregroundStyle(.secondary)
                    }
                }
                
                HStack {
                    Text("Next Refill")
                    Spacer()
                    if let nextRefill = medication.nextRefillDate {
                        Text(nextRefill, format: .dateTime.year().month().day())
                            .foregroundStyle(.secondary)
                    } else {
                        Text("—")
                            .foregroundStyle(.secondary)
                    }
                }
                
                HStack {
                    Text("ID")
                    Spacer()
                    Text(medication.id.uuidString)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .foregroundStyle(.secondary)
                        .font(.footnote.monospaced())
                }
            }
            
            Section {
                Button("Log Dose") {
                    showLogDose = true
                }
                .buttonStyle(.borderedProminent)
            }
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
