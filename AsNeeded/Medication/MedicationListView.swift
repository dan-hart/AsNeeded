// MedicationListView.swift
// SwiftUI view displaying all medications and navigation to add/edit/detail screens.

import SwiftUI
import ANModelKit

struct MedicationListView: View {
    @StateObject private var viewModel = MedicationListViewModel()
    @State private var showAddSheet = false
    @State private var editMedication: ANMedicationConcept?
    @State private var viewMedication: ANMedicationConcept?
    @State private var logMedication: ANMedicationConcept?
    @State private var pendingDelete: ANMedicationConcept?
    
    var body: some View {
        NavigationStack {
            Group {
                if viewModel.items.isEmpty {
                    VStack {
                        Spacer()
                        Text("No medications found.")
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                } else {
                    List {
                        ForEach(viewModel.items) { med in
                            HStack {
                                MedicationRow(medication: med) {
                                    logMedication = med
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture { viewMedication = med }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button {
                                    editMedication = med
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(.blue)

                                Button(role: .destructive) {
                                    pendingDelete = med
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
                        Task { await viewModel.update(updated); editMedication = nil }
                    },
                    onCancel: { editMedication = nil }
                )
            }
            .sheet(isPresented: $showAddSheet) {
                MedicationEditView(
                    medication: nil,
                    onSave: { newMed in
                        Task { await viewModel.add(newMed); showAddSheet = false }
                    },
                    onCancel: { showAddSheet = false }
                )
            }
            .sheet(item: $viewMedication) { med in
                NavigationView {
                    MedicationDetailView(medication: med)
                }
            }
            .sheet(item: $logMedication) { med in
                LogDoseView(medication: med) { dose, event in
                    Task {
                        var updated = med
                        if let quantity = updated.quantity, dose.amount > 0 {
                            updated.quantity = quantity - dose.amount
                        }
                        await viewModel.update(updated)
                        await viewModel.addEvent(event)
                        logMedication = nil
                    }
                }
                .presentationDetents([.medium, .large])
            }
            .alert("Delete Medication?", isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } })) {
                Button("Delete", role: .destructive) {
                    if let med = pendingDelete {
                        Task { await viewModel.delete(med); pendingDelete = nil }
                    }
                }
                Button("Cancel", role: .cancel) { pendingDelete = nil }
            } message: {
                Text("This action cannot be undone.")
            }
        }
    }
}

// MARK: - Medication Row
struct MedicationRow: View {
    let medication: ANMedicationConcept
    var onLogTapped: () -> Void = {}
    
    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text(medication.displayName.isEmpty ? medication.clinicalName : medication.displayName)
                    .font(.headline)
                extraInfoView
            }
            Spacer(minLength: 8)
            Button(action: onLogTapped) {
                Label("Log Dose", systemImage: "plus.circle.fill")
                    .labelStyle(.titleAndIcon)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityLabel("Log dose for \(medication.displayName.isEmpty ? medication.clinicalName : medication.displayName)")
            .accessibilityHint("Opens dose logging for this medication")
        }
    }
    
    @ViewBuilder
    private var extraInfoView: some View {
        if let quantity = medication.quantity {
            Text("\(quantity.formattedAmount)")
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
