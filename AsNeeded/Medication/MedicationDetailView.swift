// MedicationDetailView.swift
// SwiftUI view for showing details of a medication, including delete option.

import SwiftUI
import Boutique
import ANModelKit

struct MedicationDetailView: View {
    var medication: ANMedicationConcept
    var store = Medication.store
    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteConfirm = false
    @State private var showLogDose = false
    
    // Edit mode state
    @State private var isEditing = false
    @State private var editableQuantity: String = ""
    @State private var editableLastRefill: Date?
    @State private var editableNextRefill: Date?
    
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
                
                HStack(alignment: .center) {
                    Text("Quantity")
                    Spacer()
                    if isEditing {
                        HStack(spacing: 4) {
                            TextField("Quantity", text: $editableQuantity)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .frame(minWidth: 50)
                                .accessibilityLabel("Quantity")
                            if !editableQuantity.isEmpty {
                                Button(role: .cancel) {
                                    editableQuantity = ""
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.borderless)
                                .accessibilityLabel("Clear quantity")
                            }
                        }
                    } else {
                        if let quantity = medication.quantity {
                            Text("\(quantity.formattedAmount)")
                                .foregroundStyle(.secondary)
                        } else {
                            Text("—")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                HStack(alignment: .center) {
                    Text("Last Refill")
                    Spacer()
                    if isEditing {
                        HStack(spacing: 4) {
                            DatePicker(
                                "",
                                selection: Binding(
                                    get: { editableLastRefill ?? Date() },
                                    set: { editableLastRefill = $0 }
                                ),
                                displayedComponents: [.date]
                            )
                            .labelsHidden()
                            .datePickerStyle(.compact)
                            .accessibilityLabel("Last refill date")
                            
                            if editableLastRefill != nil {
                                Button(role: .cancel) {
                                    editableLastRefill = nil
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.borderless)
                                .accessibilityLabel("Clear last refill date")
                            }
                        }
                    } else {
                        if let lastRefill = medication.lastRefillDate {
                            Text(lastRefill, format: .dateTime.year().month().day())
                                .foregroundStyle(.secondary)
                        } else {
                            Text("—")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                HStack(alignment: .center) {
                    Text("Next Refill")
                    Spacer()
                    if isEditing {
                        HStack(spacing: 4) {
                            DatePicker(
                                "",
                                selection: Binding(
                                    get: { editableNextRefill ?? Date() },
                                    set: { editableNextRefill = $0 }
                                ),
                                displayedComponents: [.date]
                            )
                            .labelsHidden()
                            .datePickerStyle(.compact)
                            .accessibilityLabel("Next refill date")
                            
                            if editableNextRefill != nil {
                                Button(role: .cancel) {
                                    editableNextRefill = nil
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.borderless)
                                .accessibilityLabel("Clear next refill date")
                            }
                        }
                    } else {
                        if let nextRefill = medication.nextRefillDate {
                            Text(nextRefill, format: .dateTime.year().month().day())
                                .foregroundStyle(.secondary)
                        } else {
                            Text("—")
                                .foregroundStyle(.secondary)
                        }
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
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button(isEditing ? "Save" : "Edit") {
                    if isEditing {
                        // Save changes
                        var updated = medication
                        // Update quantity
                        if let quantityInt = Int(editableQuantity.trimmingCharacters(in: .whitespaces)), !editableQuantity.trimmingCharacters(in: .whitespaces).isEmpty {
                            updated.quantity = Double(quantityInt)
                        } else {
                            updated.quantity = nil
                        }
                        // Update dates
                        updated.lastRefillDate = editableLastRefill
                        updated.nextRefillDate = editableNextRefill
                        
                        Task {
                            try? await store.remove(updated)
                            try? await store.insert(updated)
                            isEditing = false
                            dismiss()
                        }
                    } else {
                        // Enter edit mode
                        editableQuantity = medication.quantity.map { String($0) } ?? ""
                        editableLastRefill = medication.lastRefillDate
                        editableNextRefill = medication.nextRefillDate
                        isEditing = true
                    }
                }
                .accessibilityIdentifier("EditSaveButton")
            }
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
            LogDoseView(medication: medication) { dose, event in
                Task {
                    var medicationToUpdate = medication
                    if let quantity = medication.quantity, dose.amount > 0 {
                        medicationToUpdate.quantity = quantity - dose.amount
                    }
                    try? await store.remove(medication)
                    try? await store.insert(medicationToUpdate)
                    // Insert the event
                    try? await ANEventConcept.store.insert(event)
                }
            }
        }
        .onChange(of: isEditing) { newValue in
            if !newValue {
                // If editing cancelled (e.g. by dismiss), revert edits
                editableQuantity = medication.quantity.map { String($0) } ?? ""
                editableLastRefill = medication.lastRefillDate
                editableNextRefill = medication.nextRefillDate
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

