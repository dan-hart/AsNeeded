import SwiftUI
import ANModelKit

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
    
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading) {
                Picker("Select Medication", selection: Binding(
                    get: {
                        if selectedMedicationID == nil {
                            return store.items.first?.id
                        }
                        return selectedMedicationID
                    },
                    set: { newValue in
                        selectedMedicationID = newValue
                    })) {
                    if store.items.isEmpty {
                        Text("No medications available").tag(UUID?.none)
                    } else {
                        ForEach(store.items) { med in
                            Text(med.displayName).tag(med.id as UUID?)
                        }
                    }
                }
                .pickerStyle(.menu)
                .padding(.horizontal)
                
                if let selected = selectedMedication {
                    if groupedHistory.isEmpty {
                        Spacer()
                        Text("No history for \(selected.displayName).")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                        Spacer()
                    } else {
                        List {
                            ForEach(groupedHistory, id: \.day) { group in
                                Section(header: Text(group.day.formatted(date: .abbreviated, time: .omitted))) {
                                    ForEach(group.entries, id: \.id) { event in
                                        if let dose = event.dose {
                                            Text("\(event.date.formatted(date: .omitted, time: .shortened)) – \(dose.amount) \(dose.unit.displayName)")
                                        } else {
                                            Text(event.date.formatted(date: .omitted, time: .shortened))
                                        }
                                    }
                                }
                            }
                        }
                        .listStyle(.insetGrouped)
                    }
                } else {
                    Spacer()
                    Text("Select a medication to see history.")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                    Spacer()
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
