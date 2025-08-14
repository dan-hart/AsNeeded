import SwiftUI

struct MedicationHistoryView: View {
    @State private var medications: [MockMedication] = MockMedication.asNeededMedications
    @State private var selectedMedicationID: UUID
    
    init() {
        // Default to first medication if available
        _selectedMedicationID = State(initialValue: MockMedication.asNeededMedications.first?.id ?? UUID())
    }
    
    var selectedMedication: MockMedication? {
        medications.first { $0.id == selectedMedicationID }
    }
    
    var groupedHistory: [(day: Date, entries: [Date])] {
        guard let selected = selectedMedication else { return [] }
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: selected.history) { date -> Date in
            calendar.startOfDay(for: date)
        }
        return grouped
            .map { (day: $0.key, entries: $0.value) }
            .sorted { $0.day > $1.day }
    }
    
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading) {
                Picker("Select Medication", selection: $selectedMedicationID) {
                    ForEach(medications) { med in
                        Text(med.name).tag(med.id)
                    }
                }
                .pickerStyle(.menu)
                .padding(.horizontal)
                
                if let selected = selectedMedication {
                    if groupedHistory.isEmpty {
                        Spacer()
                        Text("No history for \(selected.name).")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                        Spacer()
                    } else {
                        List {
                            ForEach(groupedHistory, id: \.day) { group in
                                Section(header: Text(group.day.formatted(date: .abbreviated, time: .omitted))) {
                                    ForEach(group.entries, id: \.self) { date in
                                        Text(date.formatted(date: .omitted, time: .shortened))
                                    }
                                }
                            }
                        }
                        .listStyle(.insetGrouped)
                    }
                }
            }
            .navigationTitle("Medication History")
        }
    }
}

#if DEBUG
#Preview {
    MedicationHistoryView()
}
#endif
