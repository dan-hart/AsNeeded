import SwiftUI

struct MedicationView: View {
    @State private var medications: [MockMedication] = MockMedication.asNeededMedications
    @State private var selectedMedication: MockMedication?
    
    var body: some View {
        NavigationStack {
            List(medications) { medication in
                NavigationLink(value: medication) {
                    VStack(alignment: .leading) {
                        Text(medication.name)
                            .font(.headline)
                        if let dosage = medication.dosage {
                            Text(dosage)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("AsNeeded")
            .navigationDestination(for: MockMedication.self) { medication in
                MedicationDetailView(medication: medication)
            }
        }
    }
}

#if DEBUG
#Preview {
    MedicationView()
}
#endif
