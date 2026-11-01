import ANModelKit
@testable import AsNeeded
import Foundation
import Testing
import UserNotifications

@MainActor
@Suite("Widget post-save notification reconciliation")
struct WidgetNotificationReconciliationTests {
	private let now = Date(timeIntervalSince1970: 1_800_000_000)

	private final class Client {
		var pending: [UNNotificationRequest] = []
		var delivered: [UNNotificationRequest] = []
		var added: [UNNotificationRequest] = []
		var removedPending: [String] = []
		var removedDelivered: [String] = []
		var authorized = true
		var failAdd = false
		var onAdd: (() -> Void)?
		var interface: MedicationNotificationClient {
			MedicationNotificationClient(notificationSettings: { self.authorized ? .authorized : .denied },
				pendingRequests: { self.pending }, deliveredRequests: { self.delivered },
				add: { request in
					if self.failAdd { throw Failure.injected }
					self.added.append(request)
					self.pending.removeAll { $0.identifier == request.identifier }
					self.pending.append(request)
					self.onAdd?()
				}, removePending: { ids in self.removedPending += ids; self.pending.removeAll { ids.contains($0.identifier) } }, removeDelivered: { self.removedDelivered += $0 })
		}
	}
	private enum Failure: Error { case injected }

	private func snapshot(enabled: Bool = true) -> MedicationPersistenceSnapshot {
		let med = ANMedicationConcept(clinicalName: "Private synthetic name", quantity: 10,
			prescribedUnit: .tablet, prescribedDoseAmount: 1, minimumHoursBetweenDoses: 4,
			nextDoseNotificationEnabled: enabled)
		return MedicationPersistenceSnapshot(medications: [med], events: [
			ANEventConcept(eventType: .doseTaken, medication: med,
				dose: ANDoseConcept(amount: 1, unit: .tablet), date: now)
		])
	}

	private func request(id: String, medicationID: UUID, category: String) -> UNNotificationRequest {
		let content = UNMutableNotificationContent()
		content.categoryIdentifier = category
		content.userInfo = ["medicationId": medicationID.uuidString]
		return UNNotificationRequest(identifier: id, content: content, trigger: nil)
	}

	@Test("Widget saves replace the next opted-in alert and clear delivered reminders privately")
	func scheduleAfterSave() async throws {
		let snapshot = snapshot()
		let med = try #require(snapshot.medications.first)
		let client = Client()
		client.pending = [request(id: "availability.stale", medicationID: UUID(), category: MedicationAvailabilityNotificationPlanner.categoryIdentifier),
			request(id: "scheduled", medicationID: med.id, category: MedicationReminderRequest.categoryIdentifier)]
		client.delivered = [request(id: "delivered", medicationID: med.id, category: MedicationReminderRequest.categoryIdentifier)]
		await WidgetDoseNotificationReconciler(client: client.interface, readSnapshot: { snapshot }, profiles: { [:] })
			.reconcile(afterLogging: med.id, at: now)
		#expect(client.added.count == 1)
		let added = try #require(client.added.first)
		#expect(added.identifier == "availability.\(med.id.uuidString)")
		#expect(added.content.title == "Next Dose Availability")
		#expect(!added.content.body.contains(med.clinicalName))
		#expect(added.content.userInfo["medicationId"] as? String == med.id.uuidString)
		#expect((added.trigger as? UNTimeIntervalNotificationTrigger)?.timeInterval == 14_400.0)
		#expect(client.removedPending.contains("availability.stale"))
		#expect(!client.removedPending.contains("scheduled"))
		#expect(client.removedDelivered.contains("delivered"))
	}

	@Test("Opt-out and denied permission remove stale availability without adding alerts", arguments: [true, false])
	func optOutAndDenied(_ authorized: Bool) async throws {
		let snapshot = snapshot(enabled: !authorized)
		let med = try #require(snapshot.medications.first)
		let client = Client()
		client.authorized = authorized
		client.pending = [request(id: "availability.stale", medicationID: med.id, category: MedicationAvailabilityNotificationPlanner.categoryIdentifier)]
		await WidgetDoseNotificationReconciler(client: client.interface, readSnapshot: { snapshot }, profiles: { [:] })
			.reconcile(afterLogging: med.id, at: now)
		#expect(client.added.isEmpty)
		#expect(client.removedPending.contains("availability.stale"))
	}

	@Test("A medication deleted during an asynchronous add cannot regain a notification")
	func deletionDuringAdd() async throws {
		var current = snapshot()
		let id = try #require(current.medications.first?.id)
		let client = Client()
		client.onAdd = { current = MedicationPersistenceSnapshot(medications: [], events: []) }
		await WidgetDoseNotificationReconciler(client: client.interface, readSnapshot: { current }, profiles: { [:] })
			.reconcile(afterLogging: id, at: now)
		#expect(client.added.count == 1)
		#expect(client.removedPending.contains("availability.\(id.uuidString)"))
	}

	@Test("Concurrent edits and doses reconcile the newer window instead of deleting it", arguments: [true, false])
	func concurrentChange(_ edit: Bool) async throws {
		var current = snapshot()
		let med = try #require(current.medications.first)
		current.medications[0].maximumDailyDoseAmount = 2
		let client = Client()
		client.onAdd = {
			guard client.added.count == 1 else { return }
			if edit {
				current.medications[0].minimumHoursBetweenDoses = 8
			} else {
				current.events.append(ANEventConcept(eventType: .doseTaken, medication: med,
					dose: ANDoseConcept(amount: 1, unit: .tablet), date: now))
			}
		}
		defer { client.onAdd = nil }
		await WidgetDoseNotificationReconciler(client: client.interface, readSnapshot: { current }, profiles: { [:] })
			.reconcile(afterLogging: med.id, at: now)
		#expect(client.added.count == 2)
		let pending = try #require(client.pending.first)
		let trigger = try #require(pending.trigger as? UNTimeIntervalNotificationTrigger)
		#expect(trigger.timeInterval == (edit ? 28_800.0 : 86_400.0))
	}

	@Test("Read and scheduling failures leave no stale availability", arguments: [true, false])
	func failures(_ readFails: Bool) async throws {
		let snapshot = snapshot()
		let id = try #require(snapshot.medications.first?.id)
		let client = Client()
		client.failAdd = !readFails
		client.pending = [request(id: "availability.\(id.uuidString)", medicationID: id, category: MedicationAvailabilityNotificationPlanner.categoryIdentifier)]
		await WidgetDoseNotificationReconciler(client: client.interface, readSnapshot: {
			if readFails { throw Failure.injected }
			return snapshot
		}, profiles: { [:] }).reconcile(afterLogging: id, at: now)
		#expect(client.removedPending.contains("availability.\(id.uuidString)"))
	}
}
