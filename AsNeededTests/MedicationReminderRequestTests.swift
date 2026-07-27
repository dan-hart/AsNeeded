@testable import ANModelKit
@testable import AsNeeded
import Foundation
import Testing
import UserNotifications

@Suite("Medication Reminder Request Tests", .tags(.service, .notifications, .unit))
struct MedicationReminderRequestTests {
	private let calendar: Calendar = {
		var calendar = Calendar(identifier: .gregorian)
		calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
		return calendar
	}()

	@Test("Request is time sensitive")
	func requestIsTimeSensitive() {
		let medication = makeMedication()
		let request = makeRequest(for: medication)

		#expect(request.content.interruptionLevel == .timeSensitive)
		#expect(request.content.categoryIdentifier == MedicationReminderRequest.categoryIdentifier)
		#expect(request.content.userInfo[MedicationReminderRequest.medicationIDKey] as? String == medication.id.uuidString)
		#expect(request.content.sound == .default)
	}

	@Test("Request shows medication names when enabled")
	func requestShowsMedicationNamesWhenEnabled() {
		let medication = makeMedication()
		let request = MedicationReminderRequest.make(
			medication: medication,
			date: Date(timeIntervalSince1970: 1_800_000_000),
			isRecurring: false,
			showMedicationNames: true,
			calendar: calendar
		)

		#expect(request.content.title == medication.displayName)
		#expect(request.content.body == "It's time to take \(medication.displayName)")
	}

	@Test("Request hides medication names when disabled")
	func requestHidesMedicationNamesWhenDisabled() {
		let request = makeRequest(showMedicationNames: false)

		#expect(request.content.title == "Medication Reminder")
		#expect(request.content.body == "It's time to take your medication")
	}

	@Test("Equivalent daily reminders have stable identifiers")
	func equivalentDailyRemindersHaveStableIdentifiers() {
		let medication = makeMedication()
		let interval = DateComponents(year: 2030, month: 4, day: 2, hour: 8, minute: 30, second: 45)
		let first = MedicationReminderRequest.make(medication: medication, date: Date(timeIntervalSince1970: 1_800_000_000), isRecurring: true, repeatInterval: interval, showMedicationNames: false, calendar: calendar)
		let second = MedicationReminderRequest.make(medication: medication, date: Date(timeIntervalSince1970: 1_900_000_000), isRecurring: true, repeatInterval: interval, showMedicationNames: false, calendar: calendar)

		#expect(first.identifier == second.identifier)
	}

	@Test("Different recurring times have different identifiers")
	func differentRecurringTimesHaveDifferentIdentifiers() {
		let medication = makeMedication()
		let first = MedicationReminderRequest.make(medication: medication, date: Date(), isRecurring: true, repeatInterval: DateComponents(hour: 8, minute: 30), showMedicationNames: false, calendar: calendar)
		let second = MedicationReminderRequest.make(medication: medication, date: Date(), isRecurring: true, repeatInterval: DateComponents(hour: 9, minute: 30), showMedicationNames: false, calendar: calendar)

		#expect(first.identifier != second.identifier)
	}

	@Test("Recurring trigger components discard source date fields")
	func recurringTriggerComponentsDiscardSourceDateFields() {
		var interval = DateComponents(year: 2030, month: 4, day: 2, hour: 8, minute: 30, second: 45)
		interval.weekday = 3
		let request = MedicationReminderRequest.make(
			medication: makeMedication(),
			date: Date(),
			isRecurring: true,
			repeatInterval: interval,
			showMedicationNames: false,
			calendar: calendar
		)

		let trigger = request.trigger as? UNCalendarNotificationTrigger
		#expect(trigger?.dateComponents.weekday == 3)
		#expect(trigger?.dateComponents.hour == 8)
		#expect(trigger?.dateComponents.minute == 30)
		#expect(trigger?.dateComponents.year == nil)
		#expect(trigger?.dateComponents.month == nil)
		#expect(trigger?.dateComponents.day == nil)
		#expect(trigger?.dateComponents.second == nil)
	}

	@Test("Different weekly weekdays have different identifiers")
	func differentWeeklyWeekdaysHaveDifferentIdentifiers() {
		let medication = makeMedication()
		var monday = DateComponents(hour: 8, minute: 30)
		monday.weekday = 2
		var tuesday = DateComponents(hour: 8, minute: 30)
		tuesday.weekday = 3
		let first = MedicationReminderRequest.make(medication: medication, date: Date(), isRecurring: true, repeatInterval: monday, showMedicationNames: false, calendar: calendar)
		let second = MedicationReminderRequest.make(medication: medication, date: Date(), isRecurring: true, repeatInterval: tuesday, showMedicationNames: false, calendar: calendar)

		#expect(first.identifier != second.identifier)
	}

	@Test("One-time reminders in the same minute have stable identifiers")
	func oneTimeRemindersInSameMinuteHaveStableIdentifiers() {
		let medication = makeMedication()
		let first = MedicationReminderRequest.make(medication: medication, date: Date(timeIntervalSince1970: 1_800_000_001), isRecurring: false, showMedicationNames: false, calendar: calendar)
		let second = MedicationReminderRequest.make(medication: medication, date: Date(timeIntervalSince1970: 1_800_000_059), isRecurring: false, showMedicationNames: false, calendar: calendar)

		#expect(first.identifier == second.identifier)
	}

	@Test("One-time reminders in different minutes have different identifiers")
	func oneTimeRemindersInDifferentMinutesHaveDifferentIdentifiers() {
		let medication = makeMedication()
		let first = MedicationReminderRequest.make(medication: medication, date: Date(timeIntervalSince1970: 1_800_000_000), isRecurring: false, showMedicationNames: false, calendar: calendar)
		let second = MedicationReminderRequest.make(medication: medication, date: Date(timeIntervalSince1970: 1_800_000_060), isRecurring: false, showMedicationNames: false, calendar: calendar)

		#expect(first.identifier != second.identifier)
	}

	@Test("Duplicate filtering retains the canonical identifier")
	func duplicateFilteringRetainsCanonicalIdentifier() {
		let medication = makeMedication()
		let canonical = recurringRequest(for: medication)
		let legacy = legacyRequest(from: canonical, identifier: "\(medication.id.uuidString)-1800000000.0")

		#expect(MedicationReminderRequest.duplicateIdentifiers(in: [canonical, legacy]) == [legacy.identifier])
	}

	@Test("Duplicate filtering retains the smallest legacy identifier")
	func duplicateFilteringRetainsSmallestLegacyIdentifier() {
		let canonical = recurringRequest(for: makeMedication())
		let firstLegacy = legacyRequest(from: canonical, identifier: "legacy-100")
		let secondLegacy = legacyRequest(from: canonical, identifier: "legacy-200")
		let thirdLegacy = legacyRequest(from: canonical, identifier: "legacy-300")

		#expect(MedicationReminderRequest.duplicateIdentifiers(in: [thirdLegacy, firstLegacy, secondLegacy]) == ["legacy-200", "legacy-300"])
	}

	@Test("A single request has no duplicates")
	func singleRequestHasNoDuplicates() {
		#expect(MedicationReminderRequest.duplicateIdentifiers(in: [makeRequest()]).isEmpty)
	}

	@Test("Duplicate filtering ignores other categories")
	func duplicateFilteringIgnoresOtherCategories() {
		let canonical = recurringRequest(for: makeMedication())
		let otherCategory = request(from: canonical, identifier: "other-category", categoryIdentifier: "OTHER")

		#expect(MedicationReminderRequest.duplicateIdentifiers(in: [canonical, otherCategory]).isEmpty)
	}

	@Test("Legacy matching excludes the incoming and deterministic identifiers")
	func legacyMatchingExcludesIncomingAndDeterministicIdentifiers() {
		let medication = makeMedication()
		let canonical = recurringRequest(for: medication)
		let legacy = legacyRequest(from: canonical, identifier: "\(medication.id.uuidString)-1800000000.0")
		let anotherLegacy = legacyRequest(from: canonical, identifier: "\(medication.id.uuidString)-1800000001.0")
		let other = MedicationReminderRequest.make(medication: medication, date: Date(), isRecurring: true, repeatInterval: DateComponents(hour: 9, minute: 30), showMedicationNames: false, calendar: calendar)

		#expect(MedicationReminderRequest.legacyIdentifiers(matching: legacy, in: [canonical, legacy, anotherLegacy, other]) == [anotherLegacy.identifier])
	}

	@Test("Delivered matching only returns the target medication category")
	func deliveredMatchingOnlyReturnsTargetMedicationCategory() {
		let medication = makeMedication()
		let otherMedication = makeMedication()
		let target = makeRequest(for: medication)
		let otherMedicationRequest = makeRequest(for: otherMedication)
		let otherCategory = request(from: target, identifier: "other-category", categoryIdentifier: "OTHER")

		#expect(MedicationReminderRequest.deliveredIdentifiers(for: medication.id, in: [otherMedicationRequest, otherCategory, target]) == [target.identifier])
	}

	@Test("Delivered matching accepts requests without a trigger")
	func deliveredMatchingAcceptsRequestsWithoutATrigger() {
		let medication = makeMedication()
		let source = makeRequest(for: medication)
		let delivered = UNNotificationRequest(identifier: "delivered", content: source.content, trigger: nil)

		#expect(MedicationReminderRequest.deliveredIdentifiers(for: medication.id, in: [delivered]) == ["delivered"])
	}

	@Test("A single legacy request gets a canonical migration plan")
	func singleLegacyRequestGetsCanonicalMigrationPlan() {
		let canonical = recurringRequest(for: makeMedication())
		let legacy = legacyRequest(from: canonical, identifier: "legacy-100")

		let plans = MedicationReminderRequest.reconciliationPlans(in: [legacy])

		#expect(plans.count == 1)
		#expect(plans.first?.requestToAdd.identifier == canonical.identifier)
		#expect(plans.first?.identifiersToRemove == [legacy.identifier])
		#expect(plans.first?.requestToAdd.content.title == legacy.content.title)
		#expect(plans.first?.requestToAdd.content.interruptionLevel == .timeSensitive)
	}

	@Test("Legacy-only duplicates use the lexicographically first source")
	func legacyOnlyDuplicatesUseLexicographicallyFirstSource() {
		let canonical = recurringRequest(for: makeMedication())
		let later = request(from: canonical, identifier: "legacy-200", categoryIdentifier: MedicationReminderRequest.categoryIdentifier, title: "Later")
		let first = request(from: canonical, identifier: "legacy-100", categoryIdentifier: MedicationReminderRequest.categoryIdentifier, title: "First")

		let plans = MedicationReminderRequest.reconciliationPlans(in: [later, first])

		#expect(plans.count == 1)
		#expect(plans.first?.requestToAdd.identifier == canonical.identifier)
		#expect(plans.first?.requestToAdd.content.title == "First")
		#expect(plans.first?.identifiersToRemove == ["legacy-100", "legacy-200"])
	}

	@Test("Canonical and legacy requests clean up only the legacy identifier")
	func canonicalAndLegacyRequestsCleanUpOnlyLegacyIdentifier() {
		let canonical = recurringRequest(for: makeMedication())
		let legacy = legacyRequest(from: canonical, identifier: "legacy-100")

		let plans = MedicationReminderRequest.reconciliationPlans(in: [legacy, canonical])

		#expect(plans.count == 1)
		#expect(plans.first?.requestToAdd.identifier == canonical.identifier)
		#expect(plans.first?.identifiersToRemove == [legacy.identifier])
	}

	@Test("A current canonical request needs no reconciliation")
	func currentCanonicalRequestNeedsNoReconciliation() {
		#expect(MedicationReminderRequest.reconciliationPlans(in: [recurringRequest(for: makeMedication())]).isEmpty)
	}

	@Test("A non-time-sensitive canonical request gets a replacement plan")
	func nonTimeSensitiveCanonicalRequestGetsReplacementPlan() {
		let canonical = recurringRequest(for: makeMedication())
		let outdated = request(from: canonical, identifier: canonical.identifier, categoryIdentifier: MedicationReminderRequest.categoryIdentifier, interruptionLevel: .active)

		let plans = MedicationReminderRequest.reconciliationPlans(in: [outdated])

		#expect(plans.count == 1)
		#expect(plans.first?.requestToAdd.identifier == canonical.identifier)
		#expect(plans.first?.requestToAdd.content.interruptionLevel == .timeSensitive)
		#expect(plans.first?.identifiersToRemove.isEmpty == true)
	}

	@Test("Reconciliation plans are sorted by canonical identifier")
	func reconciliationPlansAreSortedByCanonicalIdentifier() {
		let first = legacyRequest(from: recurringRequest(for: makeMedication()), identifier: "legacy-z")
		let second = legacyRequest(from: recurringRequest(for: makeMedication()), identifier: "legacy-a")

		let plans = MedicationReminderRequest.reconciliationPlans(in: [first, second])

		#expect(plans.map(\.requestToAdd.identifier) == plans.map(\.requestToAdd.identifier).sorted())
	}

	@Test("Legacy reconciliation preserves content and normalizes recurring triggers")
	func legacyReconciliationPreservesContentAndNormalizesRecurringTriggers() {
		let medication = makeMedication()
		var weekly = DateComponents(hour: 8, minute: 30)
		weekly.weekday = 3
		let canonical = MedicationReminderRequest.make(medication: medication, date: Date(), isRecurring: true, repeatInterval: weekly, showMedicationNames: false, calendar: calendar)
		let content = canonical.content.mutableCopy() as? UNMutableNotificationContent
		#expect(content != nil)
		guard let content else {
			return
		}
		content.title = "Legacy title"
		content.interruptionLevel = .active
		var legacyComponents = DateComponents(year: 2030, month: 4, day: 2, hour: 8, minute: 30, second: 45)
		legacyComponents.weekday = 3
		let legacy = UNNotificationRequest(
			identifier: "legacy-100",
			content: content,
			trigger: UNCalendarNotificationTrigger(dateMatching: legacyComponents, repeats: true)
		)

		let plan = MedicationReminderRequest.reconciliationPlans(in: [legacy]).first
		let trigger = plan?.requestToAdd.trigger as? UNCalendarNotificationTrigger

		#expect(plan?.requestToAdd.content.title == legacy.content.title)
		#expect(plan?.requestToAdd.content.categoryIdentifier == legacy.content.categoryIdentifier)
		#expect(plan?.requestToAdd.content.userInfo[MedicationReminderRequest.medicationIDKey] as? String == legacy.content.userInfo[MedicationReminderRequest.medicationIDKey] as? String)
		#expect(plan?.requestToAdd.content.sound == legacy.content.sound)
		#expect(plan?.requestToAdd.content.interruptionLevel == .timeSensitive)
		#expect(trigger?.dateComponents.weekday == 3)
		#expect(trigger?.dateComponents.hour == 8)
		#expect(trigger?.dateComponents.minute == 30)
		#expect(trigger?.dateComponents.year == nil)
		#expect(trigger?.dateComponents.month == nil)
		#expect(trigger?.dateComponents.day == nil)
		#expect(trigger?.dateComponents.second == nil)
	}

	private func makeRequest(showMedicationNames: Bool = false) -> UNNotificationRequest {
		makeRequest(for: makeMedication(), showMedicationNames: showMedicationNames)
	}

	private func makeRequest(for medication: ANMedicationConcept, showMedicationNames: Bool = false) -> UNNotificationRequest {
		MedicationReminderRequest.make(
			medication: medication,
			date: Date(timeIntervalSince1970: 1_800_000_000),
			isRecurring: false,
			showMedicationNames: showMedicationNames,
			calendar: calendar
		)
	}

	private func recurringRequest(for medication: ANMedicationConcept) -> UNNotificationRequest {
		MedicationReminderRequest.make(
			medication: medication,
			date: Date(timeIntervalSince1970: 1_800_000_000),
			isRecurring: true,
			repeatInterval: DateComponents(hour: 8, minute: 30),
			showMedicationNames: false,
			calendar: calendar
		)
	}

	private func legacyRequest(from canonical: UNNotificationRequest, identifier: String) -> UNNotificationRequest {
		request(from: canonical, identifier: identifier, categoryIdentifier: MedicationReminderRequest.categoryIdentifier)
	}

	private func request(
		from source: UNNotificationRequest,
		identifier: String,
		categoryIdentifier: String,
		title: String? = nil,
		interruptionLevel: UNNotificationInterruptionLevel? = nil
	) -> UNNotificationRequest {
		let content = source.content.mutableCopy() as? UNMutableNotificationContent
		content?.categoryIdentifier = categoryIdentifier
		if let title {
			content?.title = title
		}
		if let interruptionLevel {
			content?.interruptionLevel = interruptionLevel
		}
		return UNNotificationRequest(identifier: identifier, content: content ?? source.content, trigger: source.trigger)
	}

	private func makeMedication() -> ANMedicationConcept {
		ANMedicationConcept(clinicalName: "Aspirin", nickname: "Pain Relief")
	}
}
