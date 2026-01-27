// MedicationListView.swift
// SwiftUI view displaying all medications and navigation to add/edit/detail screens.

import Boutique
import SFSafeSymbols
import SwiftUI

struct MedicationListView: View {
    @ObservedObject var store = Medication.store
    @State private var showAddSheet = false
    @State private var editMedication: Medication?
    @State private var viewMedication: Medication?

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
                                .tint(.accentColor)
                                Button(role: .destructive) {
                                    store.remove(med)
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
                        store.upsert(updated)
                        editMedication = nil
                    },
                    onCancel: { editMedication = nil }
                )
            }
            .sheet(isPresented: $showAddSheet) {
                MedicationEditView(
                    medication: nil,
                    onSave: { newMed in
                        store.upsert(newMed)
                        showAddSheet = false
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
    let medication: Medication
    var body: some View {
        VStack(alignment: .leading) {
            Text(medication.name)
                .font(.headline)
            if let dosage = medication.dosage {
                Text(dosage)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    MedicationListView()
}

#Preview("Empty List") {
    MedicationListView()
}

#Preview("Populated List") {
    let store = Store<Medication>(storage: .memoryOnly, cacheIdentifier: \Medication.id)
    Task { @MainActor in
        try? await store.upsert(Medication(name: "Ibuprofen", dosage: "200mg", asNeeded: true, info: "Pain relief", rxCUI: "5640", history: []))
        try? await store.upsert(Medication(name: "Aspirin", dosage: "325mg", asNeeded: false, info: "Blood thinner", rxCUI: "1191", history: []))
    }
    return MedicationListView()
}
