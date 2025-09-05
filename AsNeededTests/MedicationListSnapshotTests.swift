import XCTest
import SwiftUI
import SnapshotTesting
@testable import AsNeeded
@testable import ANModelKit

final class MedicationListSnapshotTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
    }
    
    func testMedicationRowStandardAppearance() {
        let medication = ANMedicationConcept(
            clinicalName: "Lisinopril",
            nickname: "Blood Pressure",
            quantity: 28.5,
            lastRefillDate: Calendar.current.date(byAdding: .day, value: -15, to: Date()),
            nextRefillDate: Calendar.current.date(byAdding: .day, value: 5, to: Date()),
            prescribedUnit: .tablet,
            prescribedDoseAmount: 10.0
        )
        
        let row = MedicationRow(medication: medication)
            .frame(width: 390, height: 100)
            .background(Color(.systemBackground))
        
        assertSnapshot(matching: row, as: .image(traits: .init(userInterfaceStyle: .light)))
        assertSnapshot(matching: row, as: .image(traits: .init(userInterfaceStyle: .dark)))
    }
    
    func testMedicationRowOverdueRefill() {
        let medication = ANMedicationConcept(
            clinicalName: "Albuterol",
            nickname: "Rescue Inhaler",
            quantity: 150.0,
            lastRefillDate: Calendar.current.date(byAdding: .day, value: -7, to: Date()),
            nextRefillDate: Calendar.current.date(byAdding: .day, value: -2, to: Date()),
            prescribedUnit: .puff
        )
        
        let row = MedicationRow(medication: medication)
            .frame(width: 390, height: 100)
            .background(Color(.systemBackground))
        
        assertSnapshot(matching: row, as: .image(traits: .init(userInterfaceStyle: .light)))
        assertSnapshot(matching: row, as: .image(traits: .init(userInterfaceStyle: .dark)))
    }
    
    func testMedicationRowLongName() {
        let medication = ANMedicationConcept(
            clinicalName: "Very Long Medication Name That Could Wrap to Multiple Lines",
            quantity: 250.0,
            prescribedUnit: .milligram
        )
        
        let row = MedicationRow(medication: medication)
            .frame(width: 390, height: 100)
            .background(Color(.systemBackground))
        
        assertSnapshot(matching: row, as: .image(traits: .init(userInterfaceStyle: .light)))
    }
    
    func testMedicationRowMinimalInfo() {
        let medication = ANMedicationConcept(
            clinicalName: "Vitamin D3"
        )
        
        let row = MedicationRow(medication: medication)
            .frame(width: 390, height: 100)
            .background(Color(.systemBackground))
        
        assertSnapshot(matching: row, as: .image(traits: .init(userInterfaceStyle: .light)))
    }
    
    func testSupportSuggestionViewAppearance() {
        let supportView = SupportSuggestionView()
            .frame(width: 390)
            .background(Color(.systemGroupedBackground))
        
        assertSnapshot(matching: supportView, as: .image(traits: .init(userInterfaceStyle: .light)))
        assertSnapshot(matching: supportView, as: .image(traits: .init(userInterfaceStyle: .dark)))
    }
    
    func testMedicationListWithMultipleRows() {
        let medications = [
            ANMedicationConcept(
                clinicalName: "Lisinopril",
                nickname: "Blood Pressure",
                quantity: 28.5,
                prescribedUnit: .tablet
            ),
            ANMedicationConcept(
                clinicalName: "Metformin",
                quantity: 90.0,
                prescribedUnit: .tablet
            ),
            ANMedicationConcept(
                clinicalName: "Albuterol",
                nickname: "Rescue Inhaler",
                quantity: 150.0,
                prescribedUnit: .puff
            )
        ]
        
        let listView = VStack(spacing: 8) {
            ForEach(medications) { med in
                MedicationRow(medication: med)
                    .padding(.horizontal, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemBackground))
                    )
            }
            
            SupportSuggestionView()
        }
        .frame(width: 390)
        .padding(.vertical)
        .background(Color(.systemGroupedBackground))
        
        assertSnapshot(matching: listView, as: .image(traits: .init(userInterfaceStyle: .light)))
        assertSnapshot(matching: listView, as: .image(traits: .init(userInterfaceStyle: .dark)))
    }
    
    func testMedicationRowAccessibilitySizes() {
        let medication = ANMedicationConcept(
            clinicalName: "Lisinopril",
            nickname: "Blood Pressure",
            quantity: 28.5,
            prescribedUnit: .tablet
        )
        
        let row = MedicationRow(medication: medication)
            .frame(width: 390)
            .background(Color(.systemBackground))
        
        assertSnapshot(
            matching: row,
            as: .image(traits: .init(preferredContentSizeCategory: .extraSmall))
        )
        assertSnapshot(
            matching: row,
            as: .image(traits: .init(preferredContentSizeCategory: .large))
        )
        assertSnapshot(
            matching: row,
            as: .image(traits: .init(preferredContentSizeCategory: .extraExtraExtraLarge))
        )
        assertSnapshot(
            matching: row,
            as: .image(traits: .init(preferredContentSizeCategory: .accessibilityExtraLarge))
        )
    }
    
    func testRoundedCornersAndSpacing() {
        let medications = [
            ANMedicationConcept(clinicalName: "Med 1", quantity: 10),
            ANMedicationConcept(clinicalName: "Med 2", quantity: 20),
            ANMedicationConcept(clinicalName: "Med 3", quantity: 30)
        ]
        
        let listView = VStack(spacing: 0) {
            ForEach(Array(medications.enumerated()), id: \.element.id) { index, med in
                MedicationRow(medication: med)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemBackground))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 4)
                    )
            }
            
            SupportSuggestionView()
                .padding(.bottom, 16)
        }
        .frame(width: 390)
        .background(Color(.systemGroupedBackground))
        
        assertSnapshot(matching: listView, as: .image(traits: .init(userInterfaceStyle: .light)))
    }
}