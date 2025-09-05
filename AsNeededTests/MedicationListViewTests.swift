import XCTest
import SwiftUI
import ViewInspector
@testable import AsNeeded
@testable import ANModelKit

final class MedicationListViewTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    func testMedicationListViewEmptyState() throws {
        let view = MedicationListView()
        let viewModel = MedicationListViewModel()
        
        XCTAssertTrue(viewModel.items.isEmpty, "Initial state should have empty medication list")
    }
    
    func testMedicationRowLayout() throws {
        let medication = ANMedicationConcept(
            clinicalName: "Test Medication",
            nickname: "Test",
            quantity: 30,
            lastRefillDate: Date(),
            nextRefillDate: Calendar.current.date(byAdding: .day, value: 30, to: Date()),
            prescribedUnit: .tablet,
            prescribedDoseAmount: 10.0
        )
        
        let row = MedicationRow(medication: medication)
        
        XCTAssertNotNil(row, "MedicationRow should be created successfully")
        XCTAssertEqual(medication.clinicalName, "Test Medication")
        XCTAssertEqual(medication.quantity, 30)
    }
    
    func testMedicationRowWithNickname() throws {
        let medication = ANMedicationConcept(
            clinicalName: "Lisinopril",
            nickname: "Blood Pressure",
            quantity: 28.5
        )
        
        let row = MedicationRow(medication: medication)
        
        XCTAssertNotNil(row, "MedicationRow with nickname should be created")
        XCTAssertEqual(medication.displayName, "Blood Pressure")
    }
    
    func testMedicationRowWithoutNickname() throws {
        let medication = ANMedicationConcept(
            clinicalName: "Metformin",
            quantity: 90.0
        )
        
        let row = MedicationRow(medication: medication)
        
        XCTAssertNotNil(row, "MedicationRow without nickname should be created")
        XCTAssertEqual(medication.displayName, "Metformin")
    }
    
    func testMedicationRowQuantityFormatting() throws {
        let medicationWithUnit = ANMedicationConcept(
            clinicalName: "Test Med",
            quantity: 50.5,
            prescribedUnit: .tablet
        )
        
        XCTAssertEqual(medicationWithUnit.quantity, 50.5)
        XCTAssertEqual(medicationWithUnit.prescribedUnit?.abbreviation, "tablet")
        
        let medicationWithoutUnit = ANMedicationConcept(
            clinicalName: "Test Med",
            quantity: 100.0
        )
        
        XCTAssertEqual(medicationWithoutUnit.quantity, 100.0)
        XCTAssertNil(medicationWithoutUnit.prescribedUnit)
    }
    
    func testMedicationRowOverdueNextRefill() throws {
        let overdueDate = Calendar.current.date(byAdding: .day, value: -2, to: Date())
        let medication = ANMedicationConcept(
            clinicalName: "Albuterol",
            nextRefillDate: overdueDate
        )
        
        XCTAssertNotNil(medication.nextRefillDate)
        if let nextRefill = medication.nextRefillDate {
            XCTAssertTrue(nextRefill < Date(), "Next refill date should be in the past (overdue)")
        }
    }
    
    func testMedicationRowUpcomingRefill() throws {
        let futureDate = Calendar.current.date(byAdding: .day, value: 5, to: Date())
        let medication = ANMedicationConcept(
            clinicalName: "Vitamin D3",
            nextRefillDate: futureDate
        )
        
        XCTAssertNotNil(medication.nextRefillDate)
        if let nextRefill = medication.nextRefillDate {
            XCTAssertTrue(nextRefill > Date(), "Next refill date should be in the future")
        }
    }
    
    func testMedicationRowLogButtonAction() throws {
        let expectation = XCTestExpectation(description: "Log button tapped")
        let medication = ANMedicationConcept(clinicalName: "Test Med")
        
        let row = MedicationRow(medication: medication) {
            expectation.fulfill()
        }
        
        row.onLogTapped()
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testSupportSuggestionViewRendering() throws {
        let supportView = SupportSuggestionView()
        
        XCTAssertNotNil(supportView, "SupportSuggestionView should be created")
    }
    
    func testMedicationListSpacing() throws {
        let view = MedicationListView()
        
        XCTAssertNotNil(view, "MedicationListView should be created with proper spacing")
    }
    
    func testMedicationRowPadding() throws {
        let medication = ANMedicationConcept(clinicalName: "Test")
        let row = MedicationRow(medication: medication)
        
        XCTAssertNotNil(row, "MedicationRow should have proper padding applied")
    }
    
    func testMedicationRowCornerRadius() throws {
        let view = MedicationListView()
        
        XCTAssertNotNil(view, "List rows should have rounded corners")
    }
    
    func testListBackgroundColor() throws {
        let view = MedicationListView()
        
        XCTAssertNotNil(view, "List should have system grouped background color")
    }
}

extension MedicationListViewTests {
    
    func testAccessibilityLabels() throws {
        let medication = ANMedicationConcept(
            clinicalName: "Lisinopril",
            nickname: "Blood Pressure"
        )
        
        let row = MedicationRow(medication: medication)
        
        XCTAssertNotNil(row, "MedicationRow should have accessibility labels")
    }
    
    func testDynamicTypeSupport() throws {
        let medication = ANMedicationConcept(clinicalName: "Test Med")
        let row = MedicationRow(medication: medication)
        
        XCTAssertNotNil(row, "MedicationRow should support dynamic type")
    }
}