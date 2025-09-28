import Testing
import Foundation
import Combine
@testable import AsNeeded

@Suite("NavigationManager Tests", .tags(.navigation, .unit))
struct NavigationManagerTests {
	
	@MainActor
	private func resetNavigationManager() {
		let manager = NavigationManager.shared
		manager.selectedTab = 0
		manager.clearHistoryNavigation()
	}
	
	@Test("NavigationManager singleton is accessible")
	@MainActor
	func testSingletonAccess() {
		let manager = NavigationManager.shared
		#expect(manager.selectedTab >= 0, "Initial selected tab should be valid")
	}
	
	@Test("Initial state can be reset to defaults")
	@MainActor
	func testInitialState() {
		resetNavigationManager()
		let manager = NavigationManager.shared
		
		#expect(manager.selectedTab == 0)
		#expect(manager.historyTargetDate == nil)
		#expect(manager.historyTargetMedicationID == nil)
	}
	
	@Test("Navigate to history without parameters sets tab only")
	@MainActor
	func testNavigateToHistoryWithoutParameters() {
		resetNavigationManager()
		let manager = NavigationManager.shared
		
		manager.navigateToHistory()
		
		#expect(manager.selectedTab == 1)
		#expect(manager.historyTargetDate == nil)
		#expect(manager.historyTargetMedicationID == nil)
	}
	
	@Test("Navigate to history with date sets date and tab")
	@MainActor
	func testNavigateToHistoryWithDate() {
		resetNavigationManager()
		let manager = NavigationManager.shared
		let testDate = Date()
		
		manager.navigateToHistory(date: testDate)
		
		#expect(manager.selectedTab == 1)
		#expect(manager.historyTargetDate == testDate)
		#expect(manager.historyTargetMedicationID == nil)
	}
	
	@Test("Navigate to history with medication ID sets ID and tab")
	@MainActor
	func testNavigateToHistoryWithMedicationID() {
		resetNavigationManager()
		let manager = NavigationManager.shared
		let testID = UUID().uuidString
		
		manager.navigateToHistory(medicationID: testID)
		
		#expect(manager.selectedTab == 1)
		#expect(manager.historyTargetDate == nil)
		#expect(manager.historyTargetMedicationID == testID)
	}
	
	@Test("Navigate to history with both date and medication ID")
	@MainActor
	func testNavigateToHistoryWithBothParameters() {
		resetNavigationManager()
		let manager = NavigationManager.shared
		let testDate = Date()
		let testID = UUID().uuidString
		
		manager.navigateToHistory(date: testDate, medicationID: testID)
		
		#expect(manager.selectedTab == 1)
		#expect(manager.historyTargetDate == testDate)
		#expect(manager.historyTargetMedicationID == testID)
	}
	
	@Test("Clear history navigation resets target values")
	@MainActor
	func testClearHistoryNavigation() {
		resetNavigationManager()
		let manager = NavigationManager.shared
		let testDate = Date()
		let testID = UUID().uuidString
		
		// Set some values
		manager.navigateToHistory(date: testDate, medicationID: testID)
		
		// Clear navigation
		manager.clearHistoryNavigation()
		
		#expect(manager.historyTargetDate == nil)
		#expect(manager.historyTargetMedicationID == nil)
		// Note: selectedTab should remain unchanged
		#expect(manager.selectedTab == 1)
	}
	
	@Test("Tab selection persists after clearing navigation")
	@MainActor
	func testTabSelectionPersistsAfterClear() {
		resetNavigationManager()
		let manager = NavigationManager.shared
		
		manager.navigateToHistory(date: Date(), medicationID: "test-id")
		let tabAfterNavigation = manager.selectedTab
		
		manager.clearHistoryNavigation()
		
		#expect(manager.selectedTab == tabAfterNavigation)
	}
}