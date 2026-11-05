import Foundation
import StoreKit
import SwiftUI


@MainActor
final class AppReviewManager: ObservableObject {
    static let shared = AppReviewManager()

    // MARK: - Constants

    private let minimumLaunchCount = 3
    private let minimumEventsCount = 2

	private let defaults: UserDefaults

	init(defaults: UserDefaults = .standard) {
		self.defaults = defaults
	}

    // MARK: - User Preferences

    var hasOptedOutOfReviews: Bool {
        get { defaults.bool(forKey: AsNeeded.UserDefaultsKeys.hasUserOptedOutOfReviews) }
        set {
            objectWillChange.send()
            defaults.set(newValue, forKey: AsNeeded.UserDefaultsKeys.hasUserOptedOutOfReviews)
        }
    }

    // MARK: - Engagement Tracking

    /// Call this when the app launches
    func recordAppLaunch() {
        let currentDate = Date()
        let calendar = Calendar.current

        // Increment launch count
        let currentLaunchCount = defaults.integer(forKey: AsNeeded.UserDefaultsKeys.appLaunchCount)
        defaults.set(currentLaunchCount + 1, forKey: AsNeeded.UserDefaultsKeys.appLaunchCount)

        // Update consecutive days tracking
        updateConsecutiveDaysTracking(for: currentDate, calendar: calendar)

        // Update last use date
        defaults.set(currentDate, forKey: AsNeeded.UserDefaultsKeys.lastAppUseDate)
    }

    /// Call this when user logs a medication event
    func recordMedicationEvent() {
        let currentCount = defaults.integer(forKey: AsNeeded.UserDefaultsKeys.medicationEventsCount)
        defaults.set(currentCount + 1, forKey: AsNeeded.UserDefaultsKeys.medicationEventsCount)

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
        let lastUseDate = defaults.object(forKey: AsNeeded.UserDefaultsKeys.lastAppUseDate) as? Date
        let currentConsecutiveDays = defaults.integer(forKey: AsNeeded.UserDefaultsKeys.consecutiveDaysOfUse)

        if let lastUse = lastUseDate {
            let daysBetween = calendar.dateComponents([.day], from: lastUse, to: currentDate).day ?? 0

            if daysBetween == 1 {
                // Consecutive day usage
                defaults.set(currentConsecutiveDays + 1, forKey: AsNeeded.UserDefaultsKeys.consecutiveDaysOfUse)
            } else if daysBetween > 1 {
                // Streak broken, reset to 1
                defaults.set(1, forKey: AsNeeded.UserDefaultsKeys.consecutiveDaysOfUse)
            }
            // If daysBetween == 0, it's the same day, don't change consecutive count
        } else {
            // First time using the app
            defaults.set(1, forKey: AsNeeded.UserDefaultsKeys.consecutiveDaysOfUse)
        }
    }

    // MARK: - Review Request Logic

    private enum ReviewTrigger {
        case medicationLogged
        case medicationSetupCompleted
        case consistentUsage
        case manual
    }

    private func checkAndRequestReviewIfAppropriate(trigger _: ReviewTrigger) async {
        // Check if automatic reviews are allowed (includes opt-out check)
        guard canShowAutomaticReviewRequest() else { return }

        // Check engagement criteria
        guard isEngagementCriteriaMet() else { return }

        // Show pre-review alert for automatic requests
        await requestReviewWithAlert()
    }

    private func isEngagementCriteriaMet() -> Bool {
        let launchCount = defaults.integer(forKey: AsNeeded.UserDefaultsKeys.appLaunchCount)
        let eventsCount = defaults.integer(forKey: AsNeeded.UserDefaultsKeys.medicationEventsCount)

        return launchCount >= minimumLaunchCount &&
            eventsCount >= minimumEventsCount
    }

    private func showPreReviewAlert() async {
        let alert = UIAlertController(
            title: String(localized: "Enjoying As Needed?"),
            message: String(localized: "We'd love to know how your experience has been with the app so far."),
            preferredStyle: .alert
        )

        // "Yes, I'm enjoying it" - Show review prompt
        alert.addAction(UIAlertAction(title: String(localized: "Yes, I'm enjoying it!"), style: .default) { _ in
            Task { @MainActor in
                self.recordReviewRequest()
                self.requestNativeReview()
            }
        })

        // "Not really" - Don't show review, but don't opt out permanently
        alert.addAction(UIAlertAction(title: String(localized: "Not really"), style: .default) { _ in
            Task { @MainActor in
                self.recordReviewRequest()
            }
        })

        // "Don't ask again" - Permanently opt out
        alert.addAction(UIAlertAction(title: String(localized: "Don't ask again"), style: .destructive) { _ in
            Task { @MainActor in
                self.hasOptedOutOfReviews = true
                self.recordReviewRequest()
            }
        })

        // Present the alert on the main thread
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first
        {
            window.rootViewController?.present(alert, animated: true)
        }
    }

    private func recordReviewRequest() {
        defaults.set(Date(), forKey: AsNeeded.UserDefaultsKeys.lastReviewRequestDate)
    }

    private func requestNativeReview() {
        // Check if reviews are disabled at the iOS system level
        guard canRequestReviews() else { return }

        // For TestFlight builds, open App Store URL directly
        // Native review prompts don't work in TestFlight
        if Bundle.main.isTestFlight {
            if let reviewURL = AppURLs.appStoreReview {
                UIApplication.shared.open(reviewURL)
            }
            return
        }

        // For App Store and Debug builds, use native review prompt
        if let windowScene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
            if #available(iOS 18.0, *) {
                // Use new AppStore API for iOS 18+
                AppStore.requestReview(in: windowScene)
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
        let launches = defaults.integer(forKey: AsNeeded.UserDefaultsKeys.appLaunchCount)
        let events = defaults.integer(forKey: AsNeeded.UserDefaultsKeys.medicationEventsCount)
        let consecutiveDays = defaults.integer(forKey: AsNeeded.UserDefaultsKeys.consecutiveDaysOfUse)
        let lastRequest = defaults.object(forKey: AsNeeded.UserDefaultsKeys.lastReviewRequestDate) as? Date

        return (launches, events, consecutiveDays, lastRequest)
    }

    func resetReviewPreferences() {
        defaults.removeObject(forKey: AsNeeded.UserDefaultsKeys.hasUserOptedOutOfReviews)
        defaults.removeObject(forKey: AsNeeded.UserDefaultsKeys.lastReviewRequestDate)
        hasOptedOutOfReviews = false
    }

    func resetEngagementTracking() {
        defaults.removeObject(forKey: AsNeeded.UserDefaultsKeys.appLaunchCount)
        defaults.removeObject(forKey: AsNeeded.UserDefaultsKeys.medicationEventsCount)
        defaults.removeObject(forKey: AsNeeded.UserDefaultsKeys.consecutiveDaysOfUse)
        defaults.removeObject(forKey: AsNeeded.UserDefaultsKeys.lastAppUseDate)
    }
}
