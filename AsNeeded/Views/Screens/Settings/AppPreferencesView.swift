import SwiftUI
import SFSafeSymbols

struct AppPreferencesView: View {
	@StateObject private var notificationManager = NotificationManager.shared
	@StateObject private var hapticsManager = HapticsManager.shared
	@StateObject private var appReviewManager = AppReviewManager.shared
	@AppStorage("showMedicationNamesInNotifications") private var showMedicationNames: Bool = false
	@AppStorage("hideSupportBanners") private var hideSupportBanners = false
	@AppStorage(UserDefaultsKeys.selectedFontFamily) private var selectedFontFamily: String = FontFamily.system.rawValue
	@State private var showingResetConfirmation = false
	@ScaledMetric private var sectionSpacing: CGFloat = 32
	@ScaledMetric private var itemSpacing: CGFloat = 16
	@ScaledMetric private var headerSpacing: CGFloat = 12
	@ScaledMetric private var iconSize: CGFloat = 24
	@ScaledMetric private var padding: CGFloat = 16
	@ScaledMetric private var cornerRadius: CGFloat = 12
	@ScaledMetric private var borderWidth: CGFloat = 0.5
	@ScaledMetric private var textLeadingPadding: CGFloat = 36
	@ScaledMetric private var stackItemSpacing: CGFloat = 2
	@ScaledMetric private var innerSpacing: CGFloat = 4

	var body: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: sectionSpacing) {
				// MARK: - Header
				headerSection

				// MARK: - Notifications
				notificationsSection

				// MARK: - Feedback
				feedbackSection

				// MARK: - Typography
				typographySection

				// MARK: - Privacy
				privacySection

				// MARK: - Reset
				resetSection

				Spacer(minLength: sectionSpacing)
			}
			.padding(.horizontal, padding)
			.padding(.vertical, padding)
		}
		.navigationTitle("App Preferences")
		.navigationBarTitleDisplayMode(.large)
		.onAppear {
			// Sync the initial value from NotificationManager
			showMedicationNames = notificationManager.showMedicationNames
		}
		.confirmationDialog(
			"Reset to Defaults",
			isPresented: $showingResetConfirmation,
			titleVisibility: .visible
		) {
			Button("Reset All Preferences", role: .destructive) {
				resetAllPreferences()
			}
			Button("Cancel", role: .cancel) { }
		} message: {
			Text("This will restore all app preferences to their original defaults. This cannot be undone.")
		}
	}

	// MARK: - View Components
	private var headerSection: some View {
		VStack(alignment: .leading, spacing: headerSpacing) {
			Text("Configure how As Needed behaves and interacts with you. These settings control notifications, haptic feedback, and other app behaviors.")
				.font(.body)
				.foregroundColor(.secondary)
		}
	}

	private var notificationsSection: some View {
		VStack(alignment: .leading, spacing: itemSpacing) {
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
		VStack(alignment: .leading, spacing: itemSpacing) {
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

	private var typographySection: some View {
		VStack(alignment: .leading, spacing: itemSpacing) {
			Label {
				Text("Typography", comment: "Typography section title in app preferences")
			} icon: {
				Image(systemSymbol: .textformat)
			}
			.font(.title2)
			.fontWeight(.semibold)
			.foregroundStyle(.accent)

			Text("Choose an accessibility-focused font family to improve readability throughout the app.", comment: "Description for typography settings explaining font selection purpose")
				.font(.subheadline)
				.foregroundStyle(.secondary)

			fontFamilyPicker
		}
	}

	private var fontFamilyPicker: some View {
		VStack(alignment: .leading, spacing: headerSpacing) {
			ForEach(FontFamily.allCases) { family in
				FontFamilyRow(
					fontFamily: family,
					isSelected: selectedFontFamily == family.rawValue
				) {
					selectedFontFamily = family.rawValue
				}
			}
		}
	}

	private var privacySection: some View {
		VStack(alignment: .leading, spacing: itemSpacing) {
			Label("Privacy & Reviews", systemSymbol: .shieldLefthalfFilled)
				.font(.title2)
				.fontWeight(.semibold)
				.foregroundColor(.accentColor)

			Text("Control what information is shared and how the app requests feedback from you.")
				.font(.subheadline)
				.foregroundColor(.secondary)

			VStack(spacing: headerSpacing) {
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
		VStack(alignment: .leading, spacing: headerSpacing) {
			HStack(spacing: headerSpacing) {
				Image(systemSymbol: .bellSlash)
					.font(.callout.weight(.medium))
					.frame(width: iconSize, height: iconSize)
					.foregroundColor(.secondary)

				VStack(alignment: .leading, spacing: innerSpacing) {
					Text("Notifications Disabled")
						.font(.body)
						.fontWeight(.medium)

					Text("Enable notifications in Settings > As Needed > Notifications to configure these preferences")
						.font(.caption)
						.foregroundColor(.secondary)
				}
			}
			.padding(padding)
			.background(Color(.systemGray6))
			.cornerRadius(cornerRadius)
		}
	}

	private var resetSection: some View {
		VStack(alignment: .leading, spacing: itemSpacing) {
			Label("Reset", systemSymbol: .arrowCounterclockwise)
				.font(.title2)
				.fontWeight(.semibold)
				.foregroundColor(.red)

			Text("Reset all preferences on this screen to their original default values.")
				.font(.subheadline)
				.foregroundColor(.secondary)

			Button(action: { showingResetConfirmation = true }) {
				HStack(spacing: headerSpacing) {
					Image(systemSymbol: .arrowCounterclockwise)
						.font(.callout.weight(.medium))
						.frame(width: iconSize, height: iconSize)
						.foregroundColor(.red)

					VStack(alignment: .leading, spacing: stackItemSpacing) {
						Text("Reset to Defaults")
							.font(.body)
							.fontWeight(.medium)
							.foregroundColor(.red)

						Text("Restore all preferences to original settings")
							.font(.caption)
							.foregroundColor(.secondary)
					}

					Spacer()

					Image(systemSymbol: .chevronRight)
						.font(.caption)
						.foregroundColor(.secondary)
				}
				.padding(padding)
				.background(Color(.systemBackground))
				.overlay(
					RoundedRectangle(cornerRadius: cornerRadius)
						.stroke(Color(.systemGray4), lineWidth: borderWidth)
				)
				.cornerRadius(cornerRadius)
			}
			.buttonStyle(.plain)
		}
	}

	// MARK: - Actions
	private func resetAllPreferences() {
		// Reset notification preferences
		showMedicationNames = false
		notificationManager.showMedicationNames = false

		// Reset haptic preferences
		hapticsManager.hapticsEnabled = true

		// Reset typography preferences
		selectedFontFamily = FontFamily.system.rawValue

		// Reset privacy preferences
		hideSupportBanners = false
		appReviewManager.hasOptedOutOfReviews = false

		// Reset AppReviewManager internal tracking
		appReviewManager.resetReviewPreferences()
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
	@ScaledMetric private var itemSpacing: CGFloat = 16
	@ScaledMetric private var headerSpacing: CGFloat = 12
	@ScaledMetric private var stackItemSpacing: CGFloat = 2
	@ScaledMetric private var iconSize: CGFloat = 24
	@ScaledMetric private var padding: CGFloat = 16
	@ScaledMetric private var cornerRadius: CGFloat = 12
	@ScaledMetric private var borderWidth: CGFloat = 0.5
	@ScaledMetric private var textLeadingPadding: CGFloat = 36

	var body: some View {
		VStack(alignment: .leading, spacing: itemSpacing) {
			HStack(spacing: headerSpacing) {
				Image(systemSymbol: icon)
					.font(.callout.weight(.medium))
					.frame(width: iconSize, height: iconSize)
					.foregroundColor(.accentColor)

				VStack(alignment: .leading, spacing: stackItemSpacing) {
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
				.padding(.leading, textLeadingPadding)
		}
		.padding(padding)
		.background(Color(.systemBackground))
		.overlay(
			RoundedRectangle(cornerRadius: cornerRadius)
				.stroke(Color(.systemGray4), lineWidth: borderWidth)
		)
		.cornerRadius(cornerRadius)
	}
}

// MARK: - Font Family Row
/// Reusable font family selection row component
///
/// **Visual Appearance:**
/// - Card-style layout with rounded corners and subtle border
/// - Icon, title, and short description in header
/// - Live font preview showing sample text
/// - Full accessibility description
/// - External link button for more information (when available)
/// - Selection indicator (checkmark for selected, circle for unselected)
/// - Highlighted background when selected
///
/// **Key Features:**
/// - Dynamic Type support with @ScaledMetric spacing
/// - Supports light and dark modes
/// - VoiceOver accessible with custom labels
/// - Shows live font preview using the actual font
/// - Clickable link to font provider website
///
/// **Use Cases:**
/// - Font selection in app preferences
/// - Accessibility settings font picker
/// - Font preview and comparison views
/// - Typography customization interfaces
private struct FontFamilyRow: View {
	let fontFamily: FontFamily
	let isSelected: Bool
	let onSelect: () -> Void
	@ScaledMetric private var itemSpacing: CGFloat = 16
	@ScaledMetric private var headerSpacing: CGFloat = 12
	@ScaledMetric private var stackItemSpacing: CGFloat = 2
	@ScaledMetric private var iconSize: CGFloat = 24
	@ScaledMetric private var padding: CGFloat = 16
	@ScaledMetric private var cornerRadius: CGFloat = 12
	@ScaledMetric private var borderWidth: CGFloat = 0.5
	@ScaledMetric private var sampleSpacing: CGFloat = 8

	var body: some View {
		Button(action: onSelect) {
			VStack(alignment: .leading, spacing: itemSpacing) {
				HStack(spacing: headerSpacing) {
					Image(systemSymbol: .textformat)
						.font(.callout.weight(.medium))
						.frame(width: iconSize, height: iconSize)
						.foregroundStyle(.accent)

					VStack(alignment: .leading, spacing: stackItemSpacing) {
						Text(fontFamily.displayName)
							.font(.body)
							.fontWeight(.medium)
							.foregroundStyle(.primary)

						Text(fontFamily.shortDescription)
							.font(.caption)
							.foregroundStyle(.secondary)
					}

					Spacer()

					if isSelected {
						Image(systemSymbol: .checkmarkCircleFill)
							.font(.title3)
							.foregroundStyle(.accent)
					} else {
						Image(systemSymbol: .circle)
							.font(.title3)
							.foregroundStyle(.secondary)
					}
				}

				// Sample text preview
				VStack(alignment: .leading, spacing: sampleSpacing) {
					Text("Sample:", comment: "Label for font sample text preview")
						.font(.caption2)
						.foregroundStyle(.secondary)

					Text(fontFamily.sampleText)
						.font(.customFont(fontFamily, style: .body))
						.foregroundStyle(.primary)
						.lineLimit(2)
						.multilineTextAlignment(.leading)
				}

				// Accessibility description with external link
				VStack(alignment: .leading, spacing: sampleSpacing) {
					Text(fontFamily.accessibilityDescription)
						.font(.caption)
						.foregroundStyle(.secondary)
						.lineLimit(nil)

					// External link if available
					if let infoURL = fontFamily.infoURL {
						Link(destination: infoURL) {
							HStack(spacing: 4) {
								Text("Learn more", comment: "Link text to learn more about a font")
									.font(.caption)
									.fontWeight(.medium)
								Image(systemSymbol: .arrowUpRightSquare)
									.font(.caption2)
							}
							.foregroundStyle(.accent)
						}
						.accessibilityLabel(String(localized: "Learn more about \(fontFamily.displayName)", comment: "Accessibility label for link to learn more about a specific font"))
					}
				}
			}
			.padding(padding)
			.background(isSelected ? Color.accentColor.opacity(0.05) : Color(.systemBackground))
			.overlay(
				RoundedRectangle(cornerRadius: cornerRadius)
					.stroke(isSelected ? Color.accentColor : Color(.systemGray4), lineWidth: borderWidth)
			)
			.cornerRadius(cornerRadius)
		}
		.buttonStyle(.plain)
		.accessibilityElement(children: .combine)
		.accessibilityLabel("\(fontFamily.displayName). \(fontFamily.shortDescription). \(isSelected ? String(localized: "Selected", comment: "Accessibility label indicating this option is currently selected") : String(localized: "Not selected", comment: "Accessibility label indicating this option is not currently selected"))")
		.accessibilityHint("Double tap to select this font for the app")
	}
}

// MARK: - Preview
#Preview {
	NavigationView {
		AppPreferencesView()
	}
}
