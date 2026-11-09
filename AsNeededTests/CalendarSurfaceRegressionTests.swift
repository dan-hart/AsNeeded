import ANModelKit
@testable import AsNeeded
import Foundation
import Testing
import UserNotifications

@MainActor
struct CalendarSurfaceRegressionTests {
	enum Transition: CaseIterable {
		case spring, fall
	}

	@Test("History, Trends and Widget regroup the same recorded doses across DST and travel", .timeLimit(.minutes(1)), arguments: Transition.allCases)
	func sharedDayBuckets(_ transition: Transition) async throws {
		let fixture = try Fixture(transition)
		let preferences = try IsolatedTestPreferences()
		let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
		defer { try? FileManager.default.removeItem(at: directory) }
		let store = DataStore(storageDirectory: directory, defaults: preferences.defaults, defaultsDomainName: preferences.name)
		try await store.addMedication(fixture.medication)
		for event in fixture.events { try await store.recordDose(event, shouldRecordForReview: false) }
		let snapshot = try await store.prepareForAccess()

		var activeCalendar = try calendar(in: "America/Chicago")
		let range = try #require(TrendsPeriod.sevenDays.range(calendar: activeCalendar, now: fixture.now))
		// Let each model finish its asynchronous startup read before removing the test store.
		var startupSnapshots = store.committedSnapshots().makeAsyncIterator()
		let history = MedicationHistoryViewModel(dataStore: store, selectedMedicationID: fixture.medication.id.uuidString,
			defaults: preferences.defaults, calendar: { activeCalendar }, now: { fixture.now })
		_ = try #require(await startupSnapshots.next())
		let trends = MedicationTrendsViewModel(dataStore: store, defaults: preferences.defaults, selectedMedicationID: fixture.medication.id,
			calendar: { activeCalendar }, now: { fixture.now })
		_ = try #require(await startupSnapshots.next())
		history.dateFilter = .period(.sevenDays)
		#expect(history.groupedHistory.first?.day == fixture.chicagoMidnightAfter)
		#expect(history.groupedHistory.first?.entries.map(\.id) == [fixture.events[3].id])

		// The range from Trends is complete-day History, while the normal History period includes today.
		history.dateFilter = .custom(range)
		for (zone, expectedEntries) in [
			("America/Chicago", [fixture.chicagoMidnight: Array(fixture.events.prefix(3).reversed())]),
			("America/Los_Angeles", [fixture.transitionInstant.addingTimeInterval(-86_400): Array(fixture.events.prefix(2).reversed()),
				fixture.transitionInstant: Array(fixture.events.suffix(2).reversed())]),
		] {
			activeCalendar.timeZone = try #require(TimeZone(identifier: zone))
			let grouped = history.groupedHistory
			#expect(grouped.map(\.day) == expectedEntries.keys.sorted(by: >))
			for group in grouped {
				#expect(group.entries.map(\.id) == expectedEntries[group.day]?.map(\.id))
			}
			let totals = trends.dailyTotals(in: range)
			let widget = WidgetExperienceProjection(medications: snapshot.medications, events: snapshot.events,
				selectedID: fixture.medication.id, at: fixture.now, calendar: activeCalendar)
			let usage = try #require(widget.usage)
			#expect(usage.quantitiesComplete)
			#expect(usage.days.count == 7)
			#expect(totals.map(\.day) == usage.days.map(\.date))
			#expect(totals.map(\.total) == usage.days.map(\.quantity))
			for day in usage.days {
				let events = expectedEntries[day.date] ?? []
				#expect(day.count == events.count)
				#expect(day.quantity == events.compactMap { $0.dose?.amount }.reduce(0, +))
			}
			let dayLengths = zip(usage.days, usage.days.dropFirst()).map { $1.date.timeIntervalSince($0.date) }
			#expect(dayLengths.allSatisfy { $0 == 86_400 })
			let followingMidnight = activeCalendar.startOfDay(for: fixture.now)
			let transitionMidnight = try #require(usage.days.last?.date)
			#expect(followingMidnight.timeIntervalSince(transitionMidnight) == fixture.transitionDayLength)
		}
	}

	@Test("Recurring reminders follow wall time while guidance keeps elapsed limits across DST and travel", arguments: Transition.allCases)
	func wallTimeAndElapsedLimits(_ transition: Transition) throws {
		let fixture = try Fixture(transition)
		let beforeShift = fixture.events[1].date
		let afterShift = fixture.events[2].date
		let service = MedicationDoseGuidanceService()
		let intervalEnd = beforeShift.addingTimeInterval(7200)
		let rollingEnd = afterShift.addingTimeInterval(86_400)
		let eventsThroughShift = Array(fixture.events.prefix(3))
		var capped = fixture.medication
		capped.maximumDailyDoseAmount = 0.75
		for zone in ["America/Chicago", "America/Los_Angeles"] {
			let calendar = try calendar(in: zone)
			let request = MedicationReminderRequest.make(medication: fixture.medication, date: beforeShift,
				isRecurring: true, repeatInterval: DateComponents(hour: 8, minute: 30), showMedicationNames: false, calendar: calendar)
			let trigger = try #require(request.trigger as? UNCalendarNotificationTrigger)
			#expect(trigger.repeats)
			#expect(trigger.dateComponents.hour == 8)
			#expect(trigger.dateComponents.minute == 30)
			#expect(trigger.dateComponents.timeZone == nil)
			let first = try #require(calendar.nextDate(after: beforeShift.addingTimeInterval(-86_400), matching: trigger.dateComponents, matchingPolicy: .strict))
			let second = try #require(calendar.nextDate(after: first, matching: trigger.dateComponents, matchingPolicy: .strict))
			#expect(calendar.component(.hour, from: first) == 8)
			#expect(calendar.component(.hour, from: second) == 8)
			#expect(second.timeIntervalSince(first) == fixture.transitionDayLength)

			let projection = WidgetExperienceProjection(medications: [fixture.medication], events: fixture.events,
				selectedID: fixture.medication.id, at: beforeShift, calendar: calendar)
			#expect(projection.medications.first?.nextWindow == intervalEnd)
			let rolling = WidgetExperienceProjection(medications: [capped], events: eventsThroughShift,
				selectedID: capped.id, at: afterShift, calendar: calendar)
			#expect(rolling.medications.first?.nextWindow == rollingEnd)
		}
		let early = rollingEnd.addingTimeInterval(-1)
		#expect(!service.canTakeNow(medication: capped, at: early, events: eventsThroughShift))
		#expect(service.canTakeNow(medication: capped, at: rollingEnd, events: eventsThroughShift))
	}

	private func calendar(in zone: String) throws -> Calendar {
		var calendar = Calendar(identifier: .gregorian)
		calendar.timeZone = try #require(TimeZone(identifier: zone))
		return calendar
	}

	private struct Fixture {
		let medication: ANMedicationConcept
		let now: Date
		let transitionInstant: Date
		let chicagoMidnight: Date
		let chicagoMidnightAfter: Date
		let transitionDayLength: TimeInterval
		let events: [ANEventConcept]

		init(_ transition: Transition) throws {
			let medication = ANMedicationConcept(clinicalName: "Synthetic medication", prescribedUnit: .tablet,
				prescribedDoseAmount: 0.5, minimumHoursBetweenDoses: 2)
			self.medication = medication
			let formatter = ISO8601DateFormatter()
			let spring = transition == .spring
			transitionInstant = try #require(formatter.date(from: spring ? "2026-03-08T08:00:00Z" : "2026-11-01T07:00:00Z"))
			chicagoMidnight = transitionInstant.addingTimeInterval(-7200)
			transitionDayLength = (spring ? 23 : 25) * 3600
			chicagoMidnightAfter = chicagoMidnight.addingTimeInterval(transitionDayLength)
			now = chicagoMidnightAfter.addingTimeInterval(43_200)
			let dates = [chicagoMidnight, transitionInstant.addingTimeInterval(-1800), transitionInstant.addingTimeInterval(1800), chicagoMidnightAfter]
			events = zip(dates, [0.5, 0.25, 0.75, 1.25]).map { date, amount in
				ANEventConcept(eventType: .doseTaken, medication: medication, dose: ANDoseConcept(amount: amount, unit: .tablet), date: date)
			}
		}
	}
}
