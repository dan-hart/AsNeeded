import SwiftUI
import Charts

struct MedicationTrendsView: View {
    @State private var medications: [MockMedication] = MockMedication.asNeededMedications
    @State private var selectedMedicationID: UUID
    
    init() {
        // Default to first medication if available
        _selectedMedicationID = State(initialValue: MockMedication.asNeededMedications.first?.id ?? UUID())
    }
    
    var selectedMedication: MockMedication? {
        medications.first { $0.id == selectedMedicationID }
    }
    
    // Group history by day, count entries per day
    var dailyCounts: [(day: Date, count: Int)] {
        guard let selected = selectedMedication else { return [] }
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: selected.history) { date -> Date in
            calendar.startOfDay(for: date)
        }
        return grouped
            .map { (day: $0.key, count: $0.value.count) }
            .sorted { $0.day < $1.day }
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
                    if dailyCounts.isEmpty {
                        Spacer()
                        Text("No trend data for \(selected.name).")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                        Spacer()
                    } else {
                        Chart(dailyCounts, id: \.day) { item in
                            BarMark(
                                x: .value("Day", item.day, unit: .day),
                                y: .value("Doses Taken", item.count)
                            )
                            .foregroundStyle(Color.accentColor.gradient)
                        }
                        .chartXAxis {
                            AxisMarks(values: .stride(by: .day)) { value in
                                AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                            }
                        }
                        .frame(height: 280)
                        .padding()
                    }
                }
            }
            .navigationTitle("Medication Trends")
        }
    }
}

#if DEBUG
#Preview {
    MedicationTrendsView()
}
#endif
