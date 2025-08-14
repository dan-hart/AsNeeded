import SwiftUI

struct MedicationView: View {
    @State private var medications: [MockMedication] = MockMedication.asNeededMedications
    @State private var selectedMedication: MockMedication?
    
    @State private var medicationProvider = MedicationProvider()
    
    var body: some View {
        NavigationStack {
            if medicationProvider.activeMedicationConcepts.isEmpty {
                Spacer()
                
                Text("No active medication found.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                
                Spacer()
            } else {
                List(medicationProvider.activeMedicationConcepts) { medication in
                    NavigationLink(value: medication) {
                        VStack(alignment: .leading) {
                            if let nickname = medication.nickname {
                                Text(nickname)
                                    .font(.headline)
                                Text(medication.name)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text(medication.name)
                                    .font(.headline)
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
        .onAppear {
            Task {
                /// Fetch medication data each time.
                await medicationProvider.loadDataFromHealthKit()
            }
        }
    }
}

#if DEBUG
#Preview {
    MedicationView()
}
#endif
