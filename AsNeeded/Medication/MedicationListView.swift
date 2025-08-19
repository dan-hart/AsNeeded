// MedicationListView.swift
// SwiftUI view displaying all medications and navigation to add/edit/detail screens.

import SwiftUI
import Boutique
import ANModelKit

struct MedicationListView: View {
    var store = ANMedicationConcept.store
    @State private var showAddSheet = false
    @State private var editMedication: ANMedicationConcept?
    @State private var viewMedication: ANMedicationConcept?
    
    var body: some View {
        NavigationStack {
            Group {
                if store.items.isEmpty {
                    VStack {
                        Spacer()
                        Text("No medications found.")
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                } else {
                    List {
                        ForEach(store.items) { med in
                            Button {
                                viewMedication = med
                            } label: {
                                MedicationRow(medication: med)
                            }
                            .swipeActions {
                                Button("Edit") {
                                    editMedication = med
                                }
                                .tint(.blue)
                                Button(role: .destructive) {
                                    Task {
                                        try? await store.remove(med)
                                    }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Medication")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showAddSheet = true }) {
                        Label("Add Medication", systemImage: "plus")
                    }
                }
            }
            .sheet(item: $editMedication) { med in
                MedicationEditView(
                    medication: med,
                    onSave: { updated in
                        Task {
                            try? await store.remove(updated)
                            try? await store.insert(updated)
                            editMedication = nil
                        }
                    },
                    onCancel: { editMedication = nil }
                )
            }
            .sheet(isPresented: $showAddSheet) {
                MedicationEditView(
                    medication: nil,
                    onSave: { newMed in
                        Task {
                            try? await store.insert(newMed)
                            showAddSheet = false
                        }
                    },
                    onCancel: { showAddSheet = false }
                )
            }
            .sheet(item: $viewMedication) { med in
                MedicationDetailView(medication: med)
            }
        }
    }
}

// MARK: - Medication Row
struct MedicationRow: View {
    let medication: ANMedicationConcept
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(medication.displayName.isEmpty ? medication.clinicalName : medication.displayName)
                .font(.headline)
            extraInfoView
        }
    }
    
    @ViewBuilder
    private var extraInfoView: some View {
        if let quantity = medication.quantity {
            Text("\(quantity)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        if let lastRefill = medication.lastRefillDate {
            Text("Last refill: \(lastRefill.formatted(date: .abbreviated, time: .omitted))")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        if let nextRefill = medication.nextRefillDate {
            Text("Next refill: \(nextRefill.formatted(date: .abbreviated, time: .omitted))")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    MedicationListView()
}

#Preview("Empty List") {
    MedicationListView()
}

