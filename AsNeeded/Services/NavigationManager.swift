import ANModelKit
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

    @Published var historyRequestID = UUID()
    @Published var historyTargetDate: Date?
    @Published var historyTargetMedicationID: String?
    @Published var pendingLogMedicationID: String?
    @Published var shouldShowAddMedication = false
    @Published var pendingMedicationDetail: String?

	struct WidgetTrendsScope: Hashable {
		let medicationID: UUID
		let days: Int
	}

	@Published var pendingNotificationActions: [MedicationNotificationAction] = []

	func enqueueNotificationAction(_ action: MedicationNotificationAction) {
		guard !pendingNotificationActions.contains(where: { $0.id == action.id }) else { return }
		pendingWidgetRoute = nil
		pendingLogMedicationID = nil
		pendingMedicationDetail = nil
		shouldShowLogDoseChooser = false
		pendingNotificationActions.append(action)
		selectedTab = 0
		medicationRootRequestID = UUID()
	}

	@Published var pendingWidgetRoute: WidgetNavigationRoute?
	@Published var widgetTrendsScope: WidgetTrendsScope?
	@Published var showWidgetUnavailable = false
	@Published var shouldShowLogDoseChooser = false
	@Published var medicationRootRequestID = UUID()

	init(defaults: UserDefaults = .standard) {
		_selectedTab = AppStorage(wrappedValue: 0, UserDefaultsKeys.selectedTab, store: defaults)
	}

	/// Resolve against a fresh committed snapshot before opening UI. This never writes medication data.
	@discardableResult
	func applyWidgetRoute(_ route: WidgetNavigationRoute, medications: [ANMedicationConcept]) -> Bool {
		// The newest destination replaces deferred actions, including ones blocked behind a sheet.
		pendingLogMedicationID = nil
		shouldShowLogDoseChooser = false
		pendingMedicationDetail = nil
		clearHistoryNavigation()
		showWidgetUnavailable = false
		if let id = route.medicationID, !medications.contains(where: { $0.id == id && !$0.isArchived }) {
			pendingWidgetRoute = nil
			showWidgetUnavailable = true
			return false
		}
		pendingWidgetRoute = nil
		switch route {
		case .medications:
			pendingMedicationDetail = nil
			selectedTab = 0
			medicationRootRequestID = UUID()
		case let .medication(id): navigateToMedicationDetail(medicationID: id.uuidString)
		case let .logDose(id):
			if let id { navigateToLogDose(medicationID: id.uuidString) }
			else {
				selectedTab = 0
				shouldShowLogDoseChooser = true
				medicationRootRequestID = UUID()
			}
		case let .history(id): navigateToHistory(medicationID: id.uuidString)
		case let .trends(id, days):
			guard days == 7 else { return false }
			widgetTrendsScope = WidgetTrendsScope(medicationID: id, days: days)
			selectedTab = 2
		}
		return true
	}

    /// Navigate to history tab with optional date and medication filter
    func navigateToHistory(date: Date? = nil, medicationID: String? = nil) {
        historyTargetDate = date
        historyTargetMedicationID = medicationID
		historyRequestID = UUID()
        selectedTab = 1 // History tab index
    }

    /// Navigate to medication tab to log a dose for a specific medication
    func navigateToLogDose(medicationID: String) {
        pendingMedicationDetail = nil
        pendingLogMedicationID = medicationID
		medicationRootRequestID = UUID()
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
		medicationRootRequestID = UUID()
        selectedTab = 0 // Medication tab index
    }

    /// Clear medication detail navigation state
    func clearMedicationDetailNavigation() {
        pendingMedicationDetail = nil
    }
}
