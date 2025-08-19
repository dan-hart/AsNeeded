import SwiftUI
import ANModelKit
import Foundation

struct MedicationHistoryView: View {
    @State private var selectedMedicationID: UUID?
    @State private var store = ANMedicationConcept.store
    @State private var eventStore = ANEventConcept.store
    
    var selectedMedication: ANMedicationConcept? {
        guard let selectedID = selectedMedicationID else { return nil }
        return store.items.first { $0.id == selectedID }
    }
    
    var groupedHistory: [(day: Date, entries: [ANEventConcept])] {
        guard let selectedID = selectedMedicationID else { return [] }
        let filteredEvents = eventStore.items.filter { $0.medication?.id == selectedID && $0.eventType == .doseTaken }
        guard !filteredEvents.isEmpty else { return [] }
        
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: filteredEvents) { event in
            calendar.startOfDay(for: event.date)
        }
        return grouped
            .map { (day: $0.key, entries: $0.value) }
            .sorted { $0.day > $1.day }
    }
    
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
            ForEach(groupedHistory, id: \.day) { group in
                Section(header: Text(group.day.formatted(date: .abbreviated, time: .omitted))) {
                    ForEach(group.entries, id: \.id) { event in
                        if let dose = event.dose {
                            Text("\(event.date.formatted(date: .omitted, time: .shortened)) – \(dose.amount.formattedAmount) \(dose.unit.displayName)")
                        } else {
                            Text(event.date.formatted(date: .omitted, time: .shortened))
                        }
                    }
                    .onDelete { indexSet in
                        deleteEvents(at: indexSet, in: group.day)
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
    
    @MainActor
    private func deleteEvents(at offsets: IndexSet, in groupDay: Date) {
        guard let selectedID = selectedMedicationID else { return }
        let calendar = Calendar.current
        let filteredEvents: [ANEventConcept] = eventStore.items.filter { event in
            event.medication?.id == selectedID &&
            event.eventType == .doseTaken &&
            calendar.startOfDay(for: event.date) == groupDay
        }
        let eventsToDelete = offsets.map { filteredEvents[$0] }
        
        Task {
            for event in eventsToDelete {
                try? await eventStore.remove(event)
                
                if let dose = event.dose,
                   let medicationID = event.medication?.id,
                   let medication = store.items.first(where: { $0.id == medicationID }) {
                    var updatedMedication = medication
                    if let quantity = updatedMedication.quantity {
                        updatedMedication.quantity = (quantity + dose.amount)
                    }
                    try? await store.remove(updatedMedication)
                    try? await store.insert(updatedMedication)
                }
            }
        }
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading) {
                Picker("Medication", selection: $selectedMedicationID) {
                    ForEach(store.items, id: \.id) { medication in
                        Text(medication.displayName).tag(Optional(medication.id))
                    }
                }
                .pickerStyle(.menu)
                .padding(.horizontal)
                
                if let selected = selectedMedication {
                    if groupedHistory.isEmpty {
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
                if selectedMedicationID == nil {
                    selectedMedicationID = store.items.first?.id
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

