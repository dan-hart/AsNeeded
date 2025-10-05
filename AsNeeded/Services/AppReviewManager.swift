import Foundation
import StoreKit
import SwiftUI

// Import AppStore for iOS 18+ compatibility
#if canImport(AppStore)
import AppStore
#endif

@MainActor
final class AppReviewManager: ObservableObject {
	static let shared = AppReviewManager()

	// MARK: - UserDefaults Keys
	private enum UserDefaultsKeys {
		static let appLaunchCount = "appLaunchCount"
		static let medicationEventsCount = "medicationEventsCount"
		static let lastReviewRequestDate = "lastReviewRequestDate"
		static let hasUserOptedOutOfReviews = "hasUserOptedOutOfReviews"
		static let consecutiveDaysOfUse = "consecutiveDaysOfUse"
		static let lastAppUseDate = "lastAppUseDate"
	}

	// MARK: - Constants
	private let minimumLaunchCount = 3
	private let minimumEventsCount = 2

	private init() {}

	// MARK: - User Preferences
	var hasOptedOutOfReviews: Bool {
		get { UserDefaults.standard.bool(forKey: UserDefaultsKeys.hasUserOptedOutOfReviews) }
		set {
			objectWillChange.send()
			UserDefaults.standard.set(newValue, forKey: UserDefaultsKeys.hasUserOptedOutOfReviews)
		}
	}

	// MARK: - Engagement Tracking

	/// Call this when the app launches
	func recordAppLaunch() {
		let currentDate = Date()
		let calendar = Calendar.current

		// Increment launch count
		let currentLaunchCount = UserDefaults.standard.integer(forKey: UserDefaultsKeys.appLaunchCount)
		UserDefaults.standard.set(currentLaunchCount + 1, forKey: UserDefaultsKeys.appLaunchCount)

		// Update consecutive days tracking
		updateConsecutiveDaysTracking(for: currentDate, calendar: calendar)

		// Update last use date
		UserDefaults.standard.set(currentDate, forKey: UserDefaultsKeys.lastAppUseDate)
	}

	/// Call this when user logs a medication event
	func recordMedicationEvent() {
		let currentCount = UserDefaults.standard.integer(forKey: UserDefaultsKeys.medicationEventsCount)
		UserDefaults.standard.set(currentCount + 1, forKey: UserDefaultsKeys.medicationEventsCount)

		// Check if we should request a review after this meaningful interaction
		Task {
			await checkAndRequestReviewIfAppropriate(trigger: .medicationLogged)
		}
	}

	/// Call this when user completes setup of medication routines
	func recordMedicationSetupCompleted() {
		Task {
			await checkAndRequestReviewIfAppropriate(trigger: .medicationSetupCompleted)
		}
	}

	/// Call this when user demonstrates consistent usage patterns
	func recordConsistentUsage() {
		Task {
			await checkAndRequestReviewIfAppropriate(trigger: .consistentUsage)
		}
	}

	// MARK: - Private Methods

	private func updateConsecutiveDaysTracking(for currentDate: Date, calendar: Calendar) {
		let lastUseDate = UserDefaults.standard.object(forKey: UserDefaultsKeys.lastAppUseDate) as? Date
		let currentConsecutiveDays = UserDefaults.standard.integer(forKey: UserDefaultsKeys.consecutiveDaysOfUse)

		if let lastUse = lastUseDate {
			let daysBetween = calendar.dateComponents([.day], from: lastUse, to: currentDate).day ?? 0

			if daysBetween == 1 {
				// Consecutive day usage
				UserDefaults.standard.set(currentConsecutiveDays + 1, forKey: UserDefaultsKeys.consecutiveDaysOfUse)
			} else if daysBetween > 1 {
				// Streak broken, reset to 1
				UserDefaults.standard.set(1, forKey: UserDefaultsKeys.consecutiveDaysOfUse)
			}
			// If daysBetween == 0, it's the same day, don't change consecutive count
		} else {
			// First time using the app
			UserDefaults.standard.set(1, forKey: UserDefaultsKeys.consecutiveDaysOfUse)
		}
	}

	// MARK: - Review Request Logic

	private enum ReviewTrigger {
		case medicationLogged
		case medicationSetupCompleted
		case consistentUsage
		case manual
	}

	private func checkAndRequestReviewIfAppropriate(trigger: ReviewTrigger) async {
		// Check if automatic reviews are allowed (includes opt-out check)
		guard canShowAutomaticReviewRequest() else { return }

		// Check engagement criteria
		guard isEngagementCriteriaMet() else { return }

		// Show pre-review alert for automatic requests
		await requestReviewWithAlert()
	}

	private func isEngagementCriteriaMet() -> Bool {
		let launchCount = UserDefaults.standard.integer(forKey: UserDefaultsKeys.appLaunchCount)
		let eventsCount = UserDefaults.standard.integer(forKey: UserDefaultsKeys.medicationEventsCount)

		return launchCount >= minimumLaunchCount &&
			   eventsCount >= minimumEventsCount
	}

	private func showPreReviewAlert() async {
		let alert = UIAlertController(
			title: "Enjoying As Needed?",
			message: "We'd love to know how your experience has been with the app so far.",
			preferredStyle: .alert
		)

		// "Yes, I'm enjoying it" - Show review prompt
		alert.addAction(UIAlertAction(title: "Yes, I'm enjoying it!", style: .default) { _ in
			Task { @MainActor in
				self.recordReviewRequest()
				self.requestNativeReview()
			}
		})

		// "Not really" - Don't show review, but don't opt out permanently
		alert.addAction(UIAlertAction(title: "Not really", style: .default) { _ in
			Task { @MainActor in
				self.recordReviewRequest()
			}
		})

		// "Don't ask again" - Permanently opt out
		alert.addAction(UIAlertAction(title: "Don't ask again", style: .destructive) { _ in
			Task { @MainActor in
				self.hasOptedOutOfReviews = true
				self.recordReviewRequest()
			}
		})

		// Present the alert on the main thread
		if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
		   let window = windowScene.windows.first {
			window.rootViewController?.present(alert, animated: true)
		}
	}

	private func recordReviewRequest() {
		UserDefaults.standard.set(Date(), forKey: UserDefaultsKeys.lastReviewRequestDate)
	}

	private func requestNativeReview() {
		// Check if reviews are disabled at the iOS system level
		guard canRequestReviews() else { return }

		if let windowScene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
			if #available(iOS 18.0, *) {
				// Use new AppStore API for iOS 18+
				#if canImport(AppStore)
				AppStore.requestReview(in: windowScene)
				#else
				SKStoreReviewController.requestReview(in: windowScene)
				#endif
			} else {
				// Use legacy API for iOS 17 and below
				SKStoreReviewController.requestReview(in: windowScene)
			}
		}
	}

	/// Checks if review requests are allowed at the iOS system level
	private func canRequestReviews() -> Bool {
		// The system automatically limits review requests, but we can add additional checks here
		// SKStoreReviewController.requestReview already respects system settings, but this provides explicit control
		return true // SKStoreReviewController.requestReview handles system-level restrictions automatically
	}

	// MARK: - Manual Review Request

	/// For manual review requests from the Support screen - bypasses custom alert
	func requestManualReview() async {
		// Check if reviews are allowed (both app-level and system-level)
		guard canMakeReviewRequest() else { return }

		// Always record the request
		recordReviewRequest()

		// For manual requests, skip the custom alert and go directly to Apple's review prompt
		requestNativeReview()
	}

	/// Shows the custom alert flow (used for automatic review requests)
	func requestReviewWithAlert() async {
		// Check if automatic reviews are allowed (includes opt-out check)
		guard canShowAutomaticReviewRequest() else { return }

		// Always record the request
		recordReviewRequest()

		// Show the pre-review alert for automatic requests
		await showPreReviewAlert()
	}

	/// Check for automatic review requests (includes opt-out)
	private func canShowAutomaticReviewRequest() -> Bool {
		// Check app-level opt-out first
		guard !hasOptedOutOfReviews else { return false }

		// Check system-level settings
		guard canRequestReviews() else { return false }

		return true
	}

	/// Check for manual review requests (ignores opt-out, only checks system settings)
	func canMakeReviewRequest() -> Bool {
		// Manual requests bypass the opt-out preference
		// Only check system-level settings
		return canRequestReviews()
	}

	// MARK: - Settings and Debug Info

	func getEngagementStats() -> (launches: Int, events: Int, consecutiveDays: Int, lastRequest: Date?) {
		let launches = UserDefaults.standard.integer(forKey: UserDefaultsKeys.appLaunchCount)
		let events = UserDefaults.standard.integer(forKey: UserDefaultsKeys.medicationEventsCount)
		let consecutiveDays = UserDefaults.standard.integer(forKey: UserDefaultsKeys.consecutiveDaysOfUse)
		let lastRequest = UserDefaults.standard.object(forKey: UserDefaultsKeys.lastReviewRequestDate) as? Date

		return (launches, events, consecutiveDays, lastRequest)
	}

	func resetReviewPreferences() {
		UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.hasUserOptedOutOfReviews)
		UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.lastReviewRequestDate)
		hasOptedOutOfReviews = false
	}

	func resetEngagementTracking() {
		UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.appLaunchCount)
		UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.medicationEventsCount)
		UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.consecutiveDaysOfUse)
		UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.lastAppUseDate)
	}
}
