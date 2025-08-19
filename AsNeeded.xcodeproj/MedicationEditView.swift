// MedicationEditView.swift
// SwiftUI view for adding or editing a medication, with RxNorm lookup support.

import SwiftUI
import Boutique
import SwiftRxNorm

struct MedicationEditView: View {
    @State private var name: String
    @State private var dosage: String
    @State private var asNeeded: Bool
    @State private var info: String
    @State private var rxCUI: String?
    @State private var searching = false
    @State private var searchResults: [RxNormDrug] = []
    @State private var searchError: String?
    
    let medication: Medication?
    let onSave: (Medication) -> Void
    let onCancel: () -> Void

    init(medication: Medication?, onSave: @escaping (Medication) -> Void, onCancel: @escaping () -> Void) {
        self.medication = medication
        _name = State(initialValue: medication?.name ?? "")
        _dosage = State(initialValue: medication?.dosage ?? "")
        _asNeeded = State(initialValue: medication?.asNeeded ?? false)
        _info = State(initialValue: medication?.info ?? "")
        _rxCUI = State(initialValue: medication?.rxCUI)
        self.onSave = onSave
        self.onCancel = onCancel
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Medication Info")) {
                    TextField("Name", text: $name)
                        .onSubmit { performRxNormSearch() }
                        .autocapitalization(.words)
                        .disableAutocorrection(true)
                    TextField("Dosage", text: $dosage)
                    Toggle("As Needed", isOn: $asNeeded)
                    TextField("Details", text: $info, axis: .vertical)
                }
                Section(header: Text("RxNorm Lookup")) {
                    if searching {
                        ProgressView("Searching...")
                    } else {
                        Button("Search RxNorm") {
                            performRxNormSearch()
                        }
                    }
                    if let error = searchError {
                        Text(error).foregroundColor(.red)
                    }
                    if !searchResults.isEmpty {
                        Picker("Select Drug", selection: Binding(
                            get: { rxCUI ?? "" },
                            set: { rxCUI = $0 }
                        )) {
                            ForEach(searchResults, id: \.rxCUI) { drug in
                                Text("\(drug.name) (rxCUI: \(drug.rxCUI))").tag(drug.rxCUI)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    if let rxCUI = rxCUI {
                        Text("Selected RxNorm: \(rxCUI)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(medication == nil ? "Add Medication" : "Edit Medication")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let updated = Medication(
                            id: medication?.id ?? UUID(),
                            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                            dosage: dosage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : dosage,
                            asNeeded: asNeeded,
                            info: info,
                            rxCUI: rxCUI,
                            history: medication?.history ?? []
                        )
                        onSave(updated)
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
    
    private func performRxNormSearch() {
        guard !name.isEmpty else { return }
        searching = true
        searchError = nil
        Task {
            let client = RxNormClient()
            do {
                let results = try await client.fetchDrugsByName(name)
                searchResults = results
                searching = false
                if let found = results.first {
                    rxCUI = found.rxCUI
                }
            } catch {
                searchError = "Drug search failed: \(error.localizedDescription)"
                searching = false
            }
        }
    }
}

#Preview {
    MedicationEditView(medication: nil, onSave: { _ in }, onCancel: {})
}

#Preview("Edit Existing Medication") {
    MedicationEditView(
        medication: Medication(
            name: "Lisinopril",
            dosage: "10mg",
            asNeeded: false,
            info: "Blood pressure management.",
            rxCUI: "29046",
            history: []),
        onSave: { _ in },
        onCancel: {}
    )
}

#Preview("Add New Medication") {
    MedicationEditView(medication: nil, onSave: { _ in }, onCancel: {})
}
