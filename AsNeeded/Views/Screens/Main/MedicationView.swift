import SwiftUI
import ANModelKit

struct MedicationView: View {
    @State private var navigationPath = NavigationPath()
	@State private var lastRootRequestID: UUID?
	@Environment(\.scenePhase) private var scenePhase
    @StateObject private var navigationManager = NavigationManager.shared

    var body: some View {
        NavigationStack(path: $navigationPath) {
            MedicationListView(navigationPath: $navigationPath)
                .navigationDestination(for: ANMedicationConcept.self) { medication in
                    MedicationDetailView(medication: medication)
                }
				.task(id: "\(navigationManager.medicationRootRequestID)|\(scenePhase)") {
					if lastRootRequestID != navigationManager.medicationRootRequestID {
						navigationPath = NavigationPath()
						lastRootRequestID = navigationManager.medicationRootRequestID
					}
					guard scenePhase == .active, let medicationID = navigationManager.pendingMedicationDetail else { return }
					do {
						let snapshot = try await DataStore.shared.prepareForAccess()
						guard !Task.isCancelled, navigationManager.pendingMedicationDetail == medicationID else { return }
						navigationManager.clearMedicationDetailNavigation()
						if let medication = LogDosePickerModel.medication(forDeepLink: medicationID, from: snapshot.medications) {
							navigationPath.append(medication)
						} else { navigationManager.showWidgetUnavailable = true }
					} catch {
						// Leave the destination pending until the app can read committed data.
					}
				}
        }
		.onChange(of: navigationManager.pendingLogMedicationID) { _, medicationID in
			guard medicationID != nil else { return }
			// The root list owns dose presentation. Reveal it when a widget link
			// arrives while another medication's detail is on the navigation stack.
			navigationPath = NavigationPath()
		}
    }
}

#Preview {
    MedicationView()
}
