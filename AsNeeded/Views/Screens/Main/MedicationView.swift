import SwiftUI
import ANModelKit

struct MedicationView: View {
    @State private var navigationPath = NavigationPath()
    @StateObject private var navigationManager = NavigationManager.shared

    var body: some View {
        NavigationStack(path: $navigationPath) {
            MedicationListView(navigationPath: $navigationPath)
                .navigationDestination(for: ANMedicationConcept.self) { medication in
                    MedicationDetailView(medication: medication)
                }
                .onChange(of: navigationManager.pendingMedicationDetail) { _, medicationID in
                    guard let medicationID = medicationID else { return }

                    // Find medication by ID and navigate to it
                    if let medication = DataStore.shared.medications.first(where: { $0.id.uuidString == medicationID }) {
                        navigationPath.append(medication)
                        navigationManager.clearMedicationDetailNavigation()
                    }
                }
        }
    }
}

#Preview {
    MedicationView()
}
