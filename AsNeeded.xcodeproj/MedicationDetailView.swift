// MedicationDetailView.swift
// SwiftUI view for showing details of a medication, including delete option.

import Boutique
import SFSafeSymbols
import SwiftUI

struct MedicationDetailView: View {
    let medication: Medication
    @ObservedObject var store = Medication.store
    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteConfirm = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(medication.name)
                    .font(.largeTitle.weight(.bold))
                if let dosage = medication.dosage {
                    Text(dosage)
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                if let info = medication.info, !info.isEmpty {
                    Text(info)
                        .padding(.top, 8)
                }
                if let rxCUI = medication.rxCUI {
                    Label("RxNorm ID: \(rxCUI)", systemImage: "pill")
                        .padding(.vertical, 4)
                }
                if let mostRecent = medication.mostRecentTaken {
                    Text("Last taken: \(mostRecent.formatted(date: .abbreviated, time: .shortened))")
                        .foregroundStyle(.secondary)
                }
                if !medication.history.isEmpty {
                    VStack(alignment: .leading) {
                        Text("History:")
                            .font(.headline)
                        ForEach(medication.history.sorted(by: >), id: \ .self) { date in
                            Text(date.formatted(date: .abbreviated, time: .shortened))
                        }
                    }
                }
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
                store.remove(medication)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        }
    }
}

#Preview {
    MedicationDetailView(medication: Medication(
        name: "Albuterol Inhaler",
        dosage: "2 puffs as needed",
        asNeeded: true,
        info: "Used for relief of asthma symptoms.",
        rxCUI: "12345",
        history: [Date().addingTimeInterval(-3600 * 24), Date()]
    ))
}

#Preview("Medication with Long History") {
    MedicationDetailView(medication: Medication(
        name: "Metformin",
        dosage: "500mg",
        asNeeded: false,
        info: "Type 2 diabetes management.",
        rxCUI: "860975",
        history: [
            Date().addingTimeInterval(-3600 * 24 * 3),
            Date().addingTimeInterval(-3600 * 24 * 2),
            Date().addingTimeInterval(-3600 * 24 * 1),
            Date(),
        ]
    ))
}
