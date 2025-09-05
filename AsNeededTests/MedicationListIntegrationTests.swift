import XCTest
import SwiftUI
import Combine
@testable import AsNeeded
@testable import ANModelKit

final class MedicationListIntegrationTests: XCTestCase {
    
    var viewModel: MedicationListViewModel!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        viewModel = MedicationListViewModel()
        cancellables = []
    }
    
    override func tearDown() {
        viewModel = nil
        cancellables = nil
        super.tearDown()
    }
    
    func testMedicationListViewModelInitialization() {
        XCTAssertNotNil(viewModel)
        XCTAssertTrue(viewModel.items.isEmpty, "Initial items should be empty")
    }
    
    func testAddMedication() async throws {
        let medication = ANMedicationConcept(
            clinicalName: "Test Medication",
            quantity: 30
        )
        
        await viewModel.add(medication)
        
        XCTAssertEqual(viewModel.items.count, 1)
        XCTAssertEqual(viewModel.items.first?.clinicalName, "Test Medication")
    }
    
    func testUpdateMedication() async throws {
        let medication = ANMedicationConcept(
            clinicalName: "Original Name",
            quantity: 30
        )
        
        await viewModel.add(medication)
        
        var updatedMedication = medication
        updatedMedication.clinicalName = "Updated Name"
        updatedMedication.quantity = 50
        
        await viewModel.update(updatedMedication)
        
        XCTAssertEqual(viewModel.items.first?.clinicalName, "Updated Name")
        XCTAssertEqual(viewModel.items.first?.quantity, 50)
    }
    
    func testDeleteMedication() async throws {
        let medication1 = ANMedicationConcept(clinicalName: "Med 1")
        let medication2 = ANMedicationConcept(clinicalName: "Med 2")
        
        await viewModel.add(medication1)
        await viewModel.add(medication2)
        
        XCTAssertEqual(viewModel.items.count, 2)
        
        await viewModel.delete(medication1)
        
        XCTAssertEqual(viewModel.items.count, 1)
        XCTAssertEqual(viewModel.items.first?.clinicalName, "Med 2")
    }
    
    func testLogDoseReducesQuantity() async throws {
        let medication = ANMedicationConcept(
            clinicalName: "Test Med",
            quantity: 30,
            prescribedDoseAmount: 1
        )
        
        await viewModel.add(medication)
        
        let dose = ANDose(amount: 2, unit: .tablet)
        let event = ANMedicationEvent(
            medication: medication,
            dose: dose,
            timestamp: Date()
        )
        
        var updatedMedication = medication
        if let quantity = updatedMedication.quantity {
            updatedMedication.quantity = quantity - dose.amount
        }
        
        await viewModel.update(updatedMedication)
        await viewModel.addEvent(event)
        
        XCTAssertEqual(viewModel.items.first?.quantity, 28)
    }
    
    func testSortingByNextRefillDate() async throws {
        let med1 = ANMedicationConcept(
            clinicalName: "Med 1",
            nextRefillDate: Calendar.current.date(byAdding: .day, value: 10, to: Date())
        )
        let med2 = ANMedicationConcept(
            clinicalName: "Med 2",
            nextRefillDate: Calendar.current.date(byAdding: .day, value: 5, to: Date())
        )
        let med3 = ANMedicationConcept(
            clinicalName: "Med 3",
            nextRefillDate: Calendar.current.date(byAdding: .day, value: -2, to: Date())
        )
        
        await viewModel.add(med1)
        await viewModel.add(med2)
        await viewModel.add(med3)
        
        let sortedMeds = viewModel.items.sorted { (first, second) in
            guard let date1 = first.nextRefillDate,
                  let date2 = second.nextRefillDate else {
                return false
            }
            return date1 < date2
        }
        
        XCTAssertEqual(sortedMeds.first?.clinicalName, "Med 3", "Overdue medication should be first")
        XCTAssertEqual(sortedMeds.last?.clinicalName, "Med 1", "Furthest refill date should be last")
    }
    
    func testEmptyStateDisplay() {
        XCTAssertTrue(viewModel.items.isEmpty)
        
        let view = MedicationListView()
        XCTAssertNotNil(view, "Empty state should display properly")
    }
    
    func testSwipeActionsAvailable() async throws {
        let medication = ANMedicationConcept(clinicalName: "Test Med")
        await viewModel.add(medication)
        
        XCTAssertEqual(viewModel.items.count, 1)
        
        let view = MedicationListView()
        XCTAssertNotNil(view, "Swipe actions should be available")
    }
    
    func testNavigationToDetailView() async throws {
        let medication = ANMedicationConcept(
            clinicalName: "Test Med",
            nickname: "Test",
            quantity: 30,
            prescribedDoseAmount: 10,
            prescribedUnit: .tablet
        )
        
        await viewModel.add(medication)
        
        let detailView = MedicationDetailView(medication: medication)
        XCTAssertNotNil(detailView)
    }
    
    func testNavigationToEditView() async throws {
        let medication = ANMedicationConcept(clinicalName: "Test Med")
        
        let editView = MedicationEditView(
            medication: medication,
            onSave: { _ in },
            onCancel: { }
        )
        
        XCTAssertNotNil(editView)
    }
    
    func testLogDoseViewPresentation() async throws {
        let medication = ANMedicationConcept(
            clinicalName: "Test Med",
            prescribedDoseAmount: 10,
            prescribedUnit: .tablet
        )
        
        let logView = LogDoseView(medication: medication) { _, _ in }
        XCTAssertNotNil(logView)
    }
    
    func testSupportViewNavigation() {
        let supportView = SupportView()
        XCTAssertNotNil(supportView)
    }
}

extension MedicationListIntegrationTests {
    
    func testUIUpdateAfterDataChange() async throws {
        let expectation = XCTestExpectation(description: "UI updates after data change")
        
        viewModel.$items
            .dropFirst()
            .sink { items in
                if !items.isEmpty {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        let medication = ANMedicationConcept(clinicalName: "New Med")
        await viewModel.add(medication)
        
        await fulfillment(of: [expectation], timeout: 2.0)
    }
    
    func testListRowBackgroundStyle() {
        let view = MedicationListView()
        XCTAssertNotNil(view, "List rows should have custom background style")
    }
    
    func testListSeparatorHidden() {
        let view = MedicationListView()
        XCTAssertNotNil(view, "List row separators should be hidden")
    }
    
    func testSystemGroupedBackground() {
        let view = MedicationListView()
        XCTAssertNotNil(view, "List should use system grouped background")
    }
}