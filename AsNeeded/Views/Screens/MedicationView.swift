import SwiftUI

struct MedicationView: View {
    @State private var medications: [MockMedication] = MockMedication.asNeededMedications
    @State private var selectedMedication: MockMedication?
        
    var body: some View {
        NavigationStack {
            if medications.isEmpty {
                Spacer()
                
                Text("No active medication found.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                
                Spacer()
            } else {
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
                .navigationTitle("Medication")
                .navigationDestination(for: MockMedication.self) { medication in
                    MedicationDetailView(medication: medication)
                }
            }
        }
    }
}

#if DEBUG
#Preview {
    MedicationView()
}
#endif
