// MedicationDetailView.swift
// SwiftUI view for showing details of a medication, including delete option.

import SwiftUI
import ANModelKit

struct MedicationDetailView: View {
    var medication: ANMedicationConcept
    @StateObject private var viewModel = MedicationDetailViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteConfirm = false
    @State private var showLogDose = false
    @State private var showEditSheet = false
    
    // Edit mode state
    @State private var isEditing = false
    @State private var editableQuantity: String = ""
    @State private var editableLastRefill: Date?
    @State private var editableNextRefill: Date?
    @State private var editablePrescribedDoseText: String = ""
    @State private var editablePrescribedUnit: ANUnitConcept?

    private var isFormValid: Bool {
        let doseText = editablePrescribedDoseText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !isEditing { return true }
        if doseText.isEmpty && editablePrescribedUnit == nil { return true }
        guard let amount = Double(doseText), amount > 0 else { return false }
        return editablePrescribedUnit != nil
    }
    
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
                            // Show abbreviated unit if available, otherwise just the amount
                            if let unit = medication.prescribedUnit {
                                Text("\(quantity.formattedAmount) \(unit.abbreviation)")
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("\(quantity.formattedAmount)")
                                    .foregroundStyle(.secondary)
                            }
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
                
                HStack(alignment: .center) {
                    Text("Prescribed Dose")
                    Spacer()
                    if isEditing {
                        HStack(spacing: 6) {
                            TextField("Amount", text: $editablePrescribedDoseText)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(minWidth: 50)
                                .accessibilityLabel("Prescribed amount")
                            Picker("Unit", selection: $editablePrescribedUnit) {
                                Text("None").tag(Optional<ANUnitConcept>.none)
                                ForEach(ANUnitConcept.allCases, id: \.self) { unit in
                                    Text(unit.displayName).tag(Optional(unit))
                                }
                            }
                            .labelsHidden()
                        }
                    } else {
                        if let amt = medication.prescribedDoseAmount, let unit = medication.prescribedUnit {
                            let unitName = unit.displayName(for: amt == 1 ? 1 : 2)
                            Text("\(amt.formattedAmount) \(unitName)")
                                .foregroundStyle(.secondary)
                        } else {
                            Text("—")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
            }
            
            Section {
                Button("Edit Medication") {
                    showEditSheet = true
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .navigationTitle("Details")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Done") { dismiss() }
            }
            ToolbarItem(placement: .topBarLeading) {
                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
        .alert("Are you sure you want to delete this medication?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                Task { await viewModel.delete(medication); dismiss() }
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
                    await viewModel.save(updated: medicationToUpdate)
                    await viewModel.log(event: event)
                }
            }
        }
        .sheet(isPresented: $showEditSheet) {
            MedicationEditView(
                medication: medication,
                onSave: { updatedMedication in
                    Task {
                        await viewModel.save(updated: updatedMedication)
                    }
                    showEditSheet = false
                },
                onCancel: {
                    showEditSheet = false
                }
            )
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
