import SwiftUI
import SFSafeSymbols

struct AppPreferencesView: View {
	@StateObject private var notificationManager = NotificationManager.shared
	@StateObject private var hapticsManager = HapticsManager.shared
	@StateObject private var appReviewManager = AppReviewManager.shared
	@AppStorage("showMedicationNamesInNotifications") private var showMedicationNames: Bool = false
	@AppStorage("hideSupportBanners") private var hideSupportBanners = false

	var body: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: 32) {
				// MARK: - Header
				headerSection

				// MARK: - Notifications
				notificationsSection

				// MARK: - Feedback
				feedbackSection

				// MARK: - Privacy
				privacySection

				Spacer(minLength: 32)
			}
			.padding(.horizontal)
			.padding(.vertical)
		}
		.navigationTitle("App Preferences")
		.navigationBarTitleDisplayMode(.large)
		.onAppear {
			// Sync the initial value from NotificationManager
			showMedicationNames = notificationManager.showMedicationNames
		}
	}

	// MARK: - View Components
	private var headerSection: some View {
		VStack(alignment: .leading, spacing: 12) {
			Text("Configure how As Needed behaves and interacts with you. These settings control notifications, haptic feedback, and other app behaviors.")
				.font(.body)
				.foregroundColor(.secondary)
		}
	}

	private var notificationsSection: some View {
		VStack(alignment: .leading, spacing: 16) {
			Label("Notifications", systemSymbol: .bell)
				.font(.title2)
				.fontWeight(.semibold)
				.foregroundColor(.accentColor)

			Text("Control how medication reminders appear and what information they display.")
				.font(.subheadline)
				.foregroundColor(.secondary)

			// Only show notification toggles if notifications are available
			if notificationManager.authorizationStatus == .authorized ||
			   notificationManager.authorizationStatus == .notDetermined {
				medicationNamesToggle
			} else {
				notificationDisabledMessage
			}
		}
	}

	private var feedbackSection: some View {
		VStack(alignment: .leading, spacing: 16) {
			Label("Feedback", systemSymbol: .iphoneRadiowavesLeftAndRight)
				.font(.title2)
				.fontWeight(.semibold)
				.foregroundColor(.accentColor)

			Text("Control how the app provides tactile feedback for your interactions and actions.")
				.font(.subheadline)
				.foregroundColor(.secondary)

			hapticsToggle
		}
	}

	private var medicationNamesToggle: some View {
		PreferenceRow(
			icon: .pills,
			title: "Show Medication Names",
			subtitle: "Display medication names in notification content",
			detail: "When enabled, medication reminders will show the specific medication name. When disabled, reminders will show generic text like 'Time for your medication' for privacy.",
			isOn: $showMedicationNames
		) { newValue in
			notificationManager.showMedicationNames = newValue
		}
	}

	private var hapticsToggle: some View {
		PreferenceRow(
			icon: .iphoneRadiowavesLeftAndRight,
			title: "Haptic Feedback",
			subtitle: "Feel touches and actions throughout the app",
			detail: "Provides tactile feedback when you interact with buttons, complete actions, or receive confirmations. Helps confirm your actions with subtle vibrations.",
			isOn: $hapticsManager.hapticsEnabled
		) { _ in
			// Provide immediate feedback when toggling
			if hapticsManager.hapticsEnabled {
				HapticsManager.shared.selectionChanged()
			}
		}
	}

	private var privacySection: some View {
		VStack(alignment: .leading, spacing: 16) {
			Label("Privacy & Reviews", systemSymbol: .shieldLefthalfFilled)
				.font(.title2)
				.fontWeight(.semibold)
				.foregroundColor(.accentColor)

			Text("Control what information is shared and how the app requests feedback from you.")
				.font(.subheadline)
				.foregroundColor(.secondary)

			VStack(spacing: 12) {
				hideSupportBannersToggle
				disableReviewRequestsToggle
			}
		}
	}

	private var hideSupportBannersToggle: some View {
		PreferenceRow(
			icon: .eyeSlash,
			title: "Hide Support Banners",
			subtitle: "Disable support reminders throughout the app",
			detail: "When enabled, support banners and donation prompts will be hidden from the app interface. You can still access support options through the Settings tab.",
			isOn: $hideSupportBanners
		) { _ in }
	}

	private var disableReviewRequestsToggle: some View {
		PreferenceRow(
			icon: .starSlash,
			title: "Disable Review Requests",
			subtitle: "Opt out of automatic app review prompts",
			detail: "When enabled, the app will not automatically ask you to rate and review. Manual review buttons in Support and Feedback screens will also be hidden.",
			isOn: $appReviewManager.hasOptedOutOfReviews
		) { _ in }
	}

	private var notificationDisabledMessage: some View {
		VStack(alignment: .leading, spacing: 12) {
			HStack(spacing: 12) {
				Image(systemSymbol: .bellSlash)
					.font(.system(size: 18, weight: .medium))
					.frame(width: 24, height: 24)
					.foregroundColor(.secondary)

				VStack(alignment: .leading, spacing: 4) {
					Text("Notifications Disabled")
						.font(.body)
						.fontWeight(.medium)

					Text("Enable notifications in Settings > As Needed > Notifications to configure these preferences")
						.font(.caption)
						.foregroundColor(.secondary)
				}
			}
			.padding(16)
			.background(Color(.systemGray6))
			.cornerRadius(12)
		}
	}
}

// MARK: - Supporting Views
private struct PreferenceRow: View {
	let icon: SFSymbol
	let title: String
	let subtitle: String
	let detail: String
	@Binding var isOn: Bool
	let onChange: (Bool) -> Void

	var body: some View {
		VStack(alignment: .leading, spacing: 16) {
			HStack(spacing: 12) {
				Image(systemSymbol: icon)
					.font(.system(size: 18, weight: .medium))
					.frame(width: 24, height: 24)
					.foregroundColor(.accentColor)

				VStack(alignment: .leading, spacing: 2) {
					Text(title)
						.font(.body)
						.fontWeight(.medium)

					Text(subtitle)
						.font(.caption)
						.foregroundColor(.secondary)
				}

				Spacer()

				Toggle("", isOn: $isOn)
					.labelsHidden()
					.onChange(of: isOn) { _, newValue in
						onChange(newValue)
					}
			}

			Text(detail)
				.font(.caption)
				.foregroundColor(.secondary)
				.padding(.leading, 36) // Align with title text
		}
		.padding(16)
		.background(Color(.systemBackground))
		.overlay(
			RoundedRectangle(cornerRadius: 12)
				.stroke(Color(.systemGray4), lineWidth: 0.5)
		)
		.cornerRadius(12)
	}
}

// MARK: - Preview
#Preview {
	NavigationView {
		AppPreferencesView()
	}
}
