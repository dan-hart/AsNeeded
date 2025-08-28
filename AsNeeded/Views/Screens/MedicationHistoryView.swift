import SwiftUI
import ANModelKit
import Foundation

struct MedicationHistoryView: View {
    @StateObject private var viewModel = MedicationHistoryViewModel()
    
    // MARK: - Private ViewBuilders
    
    @ViewBuilder
    private func emptyHistoryView(for selected: ANMedicationConcept) -> some View {
        Spacer()
        Text("No history for \(selected.displayName).")
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
        Spacer()
    }
    
    @ViewBuilder
    private func historyListView() -> some View {
        List {
            ForEach(viewModel.groupedHistory, id: \.day) { group in
                Section(header: Text(group.day.formatted(date: .abbreviated, time: .omitted))) {
                    ForEach(group.entries, id: \.id) { event in
                        if let dose = event.dose {
                            let unitName = dose.unit.displayName(for: dose.amount == 1 ? 1 : 2)
                            Text("\(event.date.formatted(date: .omitted, time: .shortened)) – \(dose.amount.formattedAmount) \(unitName)")
                        } else {
                            Text(event.date.formatted(date: .omitted, time: .shortened))
                        }
                    }
                    .onDelete { indexSet in
                        Task { await viewModel.deleteEvents(at: indexSet, in: group.day) }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
    
    @ViewBuilder
    private func selectionPromptView() -> some View {
        Spacer()
        Text("Select a medication to see history.")
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
        Spacer()
    }
    
    // MARK: - Private Methods
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading) {
                Picker("Medication", selection: $viewModel.selectedMedicationID) {
                    ForEach(viewModel.medications, id: \.id) { medication in
                        Text(medication.displayName).tag(Optional(medication.id))
                    }
                }
                .pickerStyle(.menu)
                .padding(.horizontal)
                
                if let selected = viewModel.selectedMedication {
                    if viewModel.groupedHistory.isEmpty {
                        emptyHistoryView(for: selected)
                    } else {
                        historyListView()
                    }
                } else {
                    selectionPromptView()
                }
            }
            .navigationTitle("Medication History")
            .onAppear {
                if viewModel.selectedMedicationID == nil {
                    viewModel.selectedMedicationID = viewModel.medications.first?.id
                }
            }
        }
    }
}

#if DEBUG
#Preview {
    MedicationHistoryView()
}
#endif
