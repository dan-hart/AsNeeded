import Foundation
import Testing
@testable import AsNeeded

@Suite("Medication availability notifications", .tags(.unit, .notifications))
struct MedicationAvailabilityNotificationPlannerTests {
	private let now = Date(timeIntervalSince1970: 1_800_000_000)
	private let id = UUID(uuidString: "00000000-0000-0000-0000-000000000001") ?? UUID()

	private func candidate(date: Date?, enabled: Bool = true, archived: Bool = false) -> MedicationAvailabilityNotificationPlanner.Candidate {
		.init(medicationID: id, medicationName: "Private medication", enabled: enabled, archived: archived, eligibleDate: date)
	}

	@Test("Future availability produces one stable nonrecurring notification")
	func futureAvailability() {
		let planner = MedicationAvailabilityNotificationPlanner()
		let date = now.addingTimeInterval(3600)
		let plan = planner.notifications(for: [candidate(date: date)], at: now, showMedicationNames: false)
		#expect(plan.count == 1)
		#expect(plan.first?.identifier == "availability.\(id.uuidString)")
		#expect(plan.first?.date == date)
		#expect(plan.first?.title == "Next Dose Availability")
		#expect(plan.first?.body.contains("Private medication") == false)
	}

	@Test("Disabled archived elapsed and indeterminate availability produce no notifications")
	func excludedAvailability() {
		let planner = MedicationAvailabilityNotificationPlanner()
		for item in [candidate(date: nil), candidate(date: now), candidate(date: now.addingTimeInterval(-1)), candidate(date: now.addingTimeInterval(1), enabled: false), candidate(date: now.addingTimeInterval(1), archived: true)] {
			#expect(planner.notifications(for: [item], at: now, showMedicationNames: true).isEmpty)
		}
	}

	@Test("Privacy opt in includes the medication name")
	func privacy() {
		let plan = MedicationAvailabilityNotificationPlanner().notifications(for: [candidate(date: now.addingTimeInterval(60))], at: now, showMedicationNames: true)
		#expect(plan.first?.title == "Private medication")
		#expect(plan.first?.body.contains("Private medication") == true)
	}

	@Test("Reconciliation removes stale availability while leaving scheduled reminders alone")
	func removalIsolation() {
		let planner = MedicationAvailabilityNotificationPlanner()
		let availabilityID = "availability.\(id.uuidString)"
		let scheduledID = "\(id.uuidString)-1800000000"
		#expect(planner.identifiersToRemove(pending: [availabilityID, scheduledID], desired: []) == [availabilityID])
		let desired = planner.notifications(for: [candidate(date: now.addingTimeInterval(60))], at: now, showMedicationNames: false)
		#expect(planner.identifiersToRemove(pending: [availabilityID, scheduledID], desired: desired).isEmpty)
		let replacement = planner.notifications(for: [candidate(date: now.addingTimeInterval(120))], at: now, showMedicationNames: false)
		#expect(replacement.first?.identifier == desired.first?.identifier)
		#expect(replacement.first?.date != desired.first?.date)
	}
}
