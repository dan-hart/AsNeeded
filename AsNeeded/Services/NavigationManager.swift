import Combine
import SwiftUI

/// Manages navigation state across tabs in the app
@MainActor
final class NavigationManager: ObservableObject {
    static let shared = NavigationManager()

    @AppStorage(UserDefaultsKeys.selectedTab) var selectedTab: Int = 0 {
        didSet {
            objectWillChange.send()
        }
    }

    @Published var historyTargetDate: Date?
    @Published var historyTargetMedicationID: String?
    @Published var pendingLogMedicationID: String?
    @Published var shouldShowAddMedication = false
    @Published var pendingMedicationDetail: String?

    private init() {}

    /// Navigate to history tab with optional date and medication filter
    func navigateToHistory(date: Date? = nil, medicationID: String? = nil) {
        historyTargetDate = date
        historyTargetMedicationID = medicationID
        selectedTab = 1 // History tab index
    }

    /// Navigate to medication tab to log a dose for a specific medication
    func navigateToLogDose(medicationID: String) {
        pendingLogMedicationID = medicationID
        selectedTab = 0 // Medication tab index
    }

    /// Navigate to medication tab to add a new medication
    func navigateToAddMedication() {
        shouldShowAddMedication = true
        selectedTab = 0 // Medication tab index
    }

    /// Clear navigation state
    func clearHistoryNavigation() {
        historyTargetDate = nil
        historyTargetMedicationID = nil
    }

    /// Clear log dose navigation state
    func clearLogDoseNavigation() {
        pendingLogMedicationID = nil
    }

    /// Clear add medication navigation state
    func clearAddMedicationNavigation() {
        shouldShowAddMedication = false
    }

    /// Navigate to medication detail view for a specific medication
    func navigateToMedicationDetail(medicationID: String) {
        pendingMedicationDetail = medicationID
        selectedTab = 0 // Medication tab index
    }

    /// Clear medication detail navigation state
    func clearMedicationDetailNavigation() {
        pendingMedicationDetail = nil
    }
}
