import UserNotifications

@MainActor
struct MedicationNotificationClient {
	let notificationSettings: @MainActor () async -> UNAuthorizationStatus
	let pendingRequests: @MainActor () async -> [UNNotificationRequest]
	let deliveredRequests: @MainActor () async -> [UNNotificationRequest]
	let add: @MainActor (UNNotificationRequest) async throws -> Void
	let removePending: @MainActor ([String]) -> Void
	let removeDelivered: @MainActor ([String]) -> Void
	var timeSensitiveSetting: @MainActor () async -> UNNotificationSetting = { .notSupported }

	static func live(_ center: UNUserNotificationCenter) -> Self {
		Self(
			notificationSettings: { await center.notificationSettings().authorizationStatus },
			pendingRequests: { await center.pendingNotificationRequests() },
			deliveredRequests: { await center.deliveredNotifications().map(\.request) },
			add: { try await center.add($0) },
			removePending: { center.removePendingNotificationRequests(withIdentifiers: $0) },
			removeDelivered: { center.removeDeliveredNotifications(withIdentifiers: $0) },
			timeSensitiveSetting: { await center.notificationSettings().timeSensitiveSetting }
		)
	}
}

