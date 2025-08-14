// SwiftUI view for displaying medication details and administration history.
// Expects a MockMedication (from MockMedicationData.swift) as input.

import SwiftUI

struct MedicationDetailView: View {
    let medication: MockMedication
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(medication.name)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                if let dosage = medication.dosage {
                    Text(dosage)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                
                Text(medication.info)
                    .font(.body)
                    .padding(.bottom)
                
                Divider()
                
                Text("History")
                    .font(.headline)
                if medication.history.isEmpty {
                    Text("No record of this medication being taken.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(medication.history.sorted(by: >), id: \.self) { date in
                        HStack {
                            Text(date.formatted(date: .abbreviated, time: .shortened))
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                }
                Spacer()
            }
            .padding()
        }
        .navigationTitle(medication.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#if DEBUG
#Preview {
    MedicationDetailView(medication: MockMedication.asNeededMedications.first!)
}
#endif
