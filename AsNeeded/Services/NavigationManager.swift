import SwiftUI
import Combine

/// Manages navigation state across tabs in the app
@MainActor
final class NavigationManager: ObservableObject {
	static let shared = NavigationManager()
	
	@Published var selectedTab: Int = 0
	@Published var historyTargetDate: Date?
	@Published var historyTargetMedicationID: String?
	
	private init() {}
	
	/// Navigate to history tab with optional date and medication filter
	func navigateToHistory(date: Date? = nil, medicationID: String? = nil) {
		historyTargetDate = date
		historyTargetMedicationID = medicationID
		selectedTab = 1 // History tab index
	}
	
	/// Clear navigation state
	func clearHistoryNavigation() {
		historyTargetDate = nil
		historyTargetMedicationID = nil
	}
}