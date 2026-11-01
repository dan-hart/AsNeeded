import ANModelKit
import Foundation
import UserNotifications

/// Widget processes do not own the app's store subscriptions. Reconcile explicitly after saving.
@MainActor
struct WidgetDoseNotificationReconciler {
	let client: MedicationNotificationClient
	let readSnapshot: () async throws -> MedicationPersistenceSnapshot
	let profiles: () -> [String: MedicationSafetyProfile]

	func reconcile(afterLogging medicationID: UUID, at referenceDate: Date? = nil) async {
		let planner = MedicationAvailabilityNotificationPlanner()
		let delivered = await client.deliveredRequests()
		client.removeDelivered(delivered.map(\.identifier).filter { $0.hasPrefix(MedicationAvailabilityNotificationPlanner.identifierPrefix) }
			+ MedicationReminderRequest.deliveredIdentifiers(for: medicationID, in: delivered))
		// Re-read and replace from the latest state after an overlapping app edit or dose.
		retry: for _ in 0..<3 {
			let now = referenceDate ?? .now
			let pending = await client.pendingRequests()
			let availabilityIDs = pending.map(\.identifier).filter { $0.hasPrefix(MedicationAvailabilityNotificationPlanner.identifierPrefix) }
			guard let snapshot = try? await readSnapshot() else {
				client.removePending(availabilityIDs)
				return
			}
			let authorized = await client.notificationSettings()
			let savedProfiles = profiles()
			let candidates = snapshot.medications.map { medication in
				MedicationAvailabilityNotificationPlanner.Candidate(medicationID: medication.id,
					medicationName: medication.displayName,
					enabled: [.authorized, .provisional, .ephemeral].contains(authorized) && medication.nextDoseNotificationEnabled == true,
					archived: medication.isArchived,
					eligibleDate: MedicationDoseGuidanceService().availability(for: medication, at: now,
						events: snapshot.events, profile: savedProfiles[medication.id.uuidString] ?? .empty).eligibleDate)
			}
			// App-container privacy preferences are unavailable here: keep extension-created alerts generic.
			let desired = planner.notifications(for: candidates, at: now, showMedicationNames: false)
			client.removePending(planner.identifiersToRemove(pending: pending.map(\.identifier), desired: desired))
			for notification in desired {
				guard await stillCurrent(notification.medicationID, snapshot: snapshot, profiles: savedProfiles) else {
					continue retry
				}
				let content = UNMutableNotificationContent()
				content.title = notification.title
				content.body = notification.body
				content.sound = .default
				content.categoryIdentifier = MedicationAvailabilityNotificationPlanner.categoryIdentifier
				content.userInfo = [MedicationReminderRequest.medicationIDKey: notification.medicationID.uuidString]
				let interval = notification.date.timeIntervalSince(referenceDate ?? .now)
				guard interval > 0 else {
					client.removePending([notification.identifier])
					continue
				}
				let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, interval), repeats: false)
				do {
					try await client.add(UNNotificationRequest(identifier: notification.identifier, content: content, trigger: trigger))
					// A deletion, edit, or another dose during an async add must invalidate the stale result.
					if !(await stillCurrent(notification.medicationID, snapshot: snapshot, profiles: savedProfiles)) {
						continue retry
					}
				} catch { client.removePending([notification.identifier]) }
			}
			if let current = try? await readSnapshot(), current.medications == snapshot.medications,
				current.events == snapshot.events, profiles() == savedProfiles { return }
		}
		// Repeated cross-process changes cannot be presented as known availability.
		let pending = await client.pendingRequests()
		client.removePending(pending.map(\.identifier).filter {
			$0.hasPrefix(MedicationAvailabilityNotificationPlanner.identifierPrefix)
		})
	}

	private func stillCurrent(_ id: UUID, snapshot: MedicationPersistenceSnapshot,
		profiles savedProfiles: [String: MedicationSafetyProfile]) async -> Bool {
		guard let current = try? await readSnapshot(),
			let medication = current.medications.first(where: { $0.id == id && !$0.isArchived }),
			medication == snapshot.medications.first(where: { $0.id == id }),
			profiles()[id.uuidString] == savedProfiles[id.uuidString] else { return false }
		return current.events.filter { $0.medication?.id == id } == snapshot.events.filter { $0.medication?.id == id }
	}
}
