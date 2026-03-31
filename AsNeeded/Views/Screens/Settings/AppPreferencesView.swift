import SFSafeSymbols
import SwiftUI

struct AppPreferencesView: View {
    @StateObject private var notificationManager = NotificationManager.shared
    @StateObject private var hapticsManager = HapticsManager.shared
    @StateObject private var appReviewManager = AppReviewManager.shared
    @Environment(\.fontFamily) private var fontFamily
    @AppStorage(UserDefaultsKeys.showMedicationNamesInNotifications) private var showMedicationNames: Bool = false
    @AppStorage(UserDefaultsKeys.hideSupportBanners) private var hideSupportBanners = false
    @AppStorage(UserDefaultsKeys.selectedFontFamily) private var selectedFontFamily: String = FontFamily.system.rawValue
    @AppStorage(UserDefaultsKeys.importSettingsDefaultBehavior) private var importSettingsDefaultBehavior: String = "keep"
    @AppStorage(UserDefaultsKeys.trendsQuestionsEnabled) private var trendsQuestionsEnabled = false
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

                typographyNavigationLink

                // MARK: - Privacy

                privacySection

                if MedicationTrendsQuestionSupport.isSupportedOnDevice {
                    privateQuestionsSection
                }

                // MARK: - Data Import

                dataImportSection

                // MARK: - Reset

                resetSection

                Spacer(minLength: sectionSpacing)
            }
            .padding(.horizontal, padding)
            .padding(.vertical, padding)
        }
        .customNavigationTitle("App Preferences")
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
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will restore all app preferences to their original defaults. This cannot be undone.")
        }
    }

    // MARK: - View Components

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: headerSpacing) {
            Text("Configure how As Needed behaves and interacts with you. These settings control notifications, haptic feedback, and other app behaviors.")
                .font(.customFont(fontFamily, style: .body))
                .foregroundStyle(.secondary)
        }
    }

    private var notificationsSection: some View {
        VStack(alignment: .leading, spacing: itemSpacing) {
            Label("Notifications", systemSymbol: .bell)
                .font(.customFont(fontFamily, style: .title3, weight: .semibold))
                .foregroundStyle(.accent)

            Text("Control how medication reminders appear and what information they display.")
                .font(.customFont(fontFamily, style: .subheadline))
                .foregroundStyle(.secondary)

            // Only show notification toggles if notifications are available
            if notificationManager.authorizationStatus == .authorized ||
                notificationManager.authorizationStatus == .notDetermined
            {
                medicationNamesToggle
            } else {
                notificationDisabledMessage
            }
        }
    }

    private var feedbackSection: some View {
        VStack(alignment: .leading, spacing: itemSpacing) {
            Label("Feedback", systemSymbol: .iphoneRadiowavesLeftAndRight)
                .font(.customFont(fontFamily, style: .title3, weight: .semibold))
                .foregroundStyle(.accent)

            Text("Control how the app provides tactile feedback for your interactions and actions.")
                .font(.customFont(fontFamily, style: .subheadline))
                .foregroundStyle(.secondary)

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

    private var typographyNavigationLink: some View {
        VStack(alignment: .leading, spacing: itemSpacing) {
            Label("Typography", systemSymbol: .textformat)
                .font(.customFont(fontFamily, style: .title3, weight: .semibold))
                .foregroundStyle(.accent)

            Text("Choose an accessibility-focused font family to improve readability throughout the app.")
                .font(.customFont(fontFamily, style: .subheadline))
                .foregroundStyle(.secondary)

            NavigationLink(destination: FontPreferencesView()) {
                HStack(spacing: headerSpacing) {
                    Image(systemSymbol: .textformat)
                        .font(.customFont(fontFamily, style: .callout, weight: .medium))
                        .frame(width: iconSize, height: iconSize)
                        .foregroundStyle(.accent)

                    VStack(alignment: .leading, spacing: stackItemSpacing) {
                        Text("Font Family")
                            .font(.customFont(fontFamily, style: .body, weight: .medium))
                            .foregroundStyle(.primary)

                        Text("Customize typography and readability")
                            .font(.customFont(fontFamily, style: .caption))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemSymbol: .chevronRight)
                        .font(.customFont(fontFamily, style: .caption))
                        .foregroundStyle(.secondary)
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

    private var privacySection: some View {
        VStack(alignment: .leading, spacing: itemSpacing) {
            Label("Privacy & Reviews", systemSymbol: .shieldLefthalfFilled)
                .font(.customFont(fontFamily, style: .title3, weight: .semibold))
                .foregroundStyle(.accent)

            Text("Control what information is shared and how the app requests feedback from you.")
                .font(.customFont(fontFamily, style: .subheadline))
                .foregroundStyle(.secondary)

            VStack(spacing: headerSpacing) {
                hideSupportBannersToggle
                disableReviewRequestsToggle
            }
        }
    }

    private var privateQuestionsSection: some View {
        VStack(alignment: .leading, spacing: itemSpacing) {
            Label("Private Questions", systemSymbol: .bubbleLeftAndBubbleRightFill)
                .font(.customFont(fontFamily, style: .title3, weight: .semibold))
                .foregroundStyle(.accent)

            Text("Ask the Trends tab about your own logs using on-device processing that stays private.")
                .font(.customFont(fontFamily, style: .subheadline))
                .foregroundStyle(.secondary)

            PreferenceRow(
                icon: .lockFill,
                title: "Enable On-Device Questions",
                subtitle: "Opt in before asking about medication patterns",
                detail: "When enabled, the Trends tab can answer questions about your logged medication history. For this feature, your data stays on this device and never leaves the device for processing.",
                isOn: $trendsQuestionsEnabled
            ) { _ in }

            HStack(alignment: .top, spacing: headerSpacing) {
                Image(systemSymbol: .checkmarkShieldFill)
                    .font(.customFont(fontFamily, style: .callout, weight: .medium))
                    .foregroundStyle(.accent)
                    .frame(width: iconSize, height: iconSize)

                VStack(alignment: .leading, spacing: stackItemSpacing) {
                    Text("What to expect")
                        .font(.customFont(fontFamily, style: .body, weight: .medium))
                        .foregroundStyle(.primary)

                    Text("Responses can be incorrect or incomplete, and the feature only summarizes the data you’ve already logged.")
                        .font(.customFont(fontFamily, style: .caption))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
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

    private var dataImportSection: some View {
        VStack(alignment: .leading, spacing: itemSpacing) {
            Label("Data Import Behavior", systemSymbol: .squareAndArrowDown)
                .font(.customFont(fontFamily, style: .title3, weight: .semibold))
                .foregroundStyle(.accent)

            Text("Choose how to handle app settings when importing data.")
                .font(.customFont(fontFamily, style: .subheadline))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: innerSpacing) {
                    Text("When importing settings")
                        .font(.customFont(fontFamily, style: .body, weight: .medium))

                    Picker("Import Behavior", selection: $importSettingsDefaultBehavior) {
                        Text("Always ask")
                            .font(.customFont(fontFamily, style: .body))
                            .tag("ask")
                        Text("Keep my settings by default")
                            .font(.customFont(fontFamily, style: .body))
                            .tag("keep")
                    }
                    .pickerStyle(.segmented)
                    .padding(.top, 8)

                    Text("This controls what happens when you import data that contains app settings. You can always change your choice during import.")
                        .font(.customFont(fontFamily, style: .caption))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 4)
                }
                .padding(padding)
                .background(Color(.systemGray6))
                .cornerRadius(cornerRadius)
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
                    .font(.customFont(fontFamily, style: .callout, weight: .medium))
                    .frame(width: iconSize, height: iconSize)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: innerSpacing) {
                    Text("Notifications Disabled")
                        .font(.customFont(fontFamily, style: .body, weight: .medium))

                    Text("Enable notifications in Settings > As Needed > Notifications to configure these preferences")
                        .font(.customFont(fontFamily, style: .caption))
                        .foregroundStyle(.secondary)
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
                .font(.customFont(fontFamily, style: .title3, weight: .semibold))
                .foregroundStyle(.red)

            Text("Reset all preferences on this screen to their original default values.")
                .font(.customFont(fontFamily, style: .subheadline))
                .foregroundStyle(.secondary)

            Button(action: { showingResetConfirmation = true }) {
                HStack(spacing: headerSpacing) {
                    Image(systemSymbol: .arrowCounterclockwise)
                        .font(.customFont(fontFamily, style: .callout, weight: .medium))
                        .frame(width: iconSize, height: iconSize)
                        .foregroundStyle(.red)

                    VStack(alignment: .leading, spacing: stackItemSpacing) {
                        Text("Reset to Defaults")
                            .font(.customFont(fontFamily, style: .body, weight: .medium))
                            .foregroundStyle(.red)

                        Text("Restore all preferences to original settings")
                            .font(.customFont(fontFamily, style: .caption))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemSymbol: .chevronRight)
                        .font(.customFont(fontFamily, style: .caption))
                        .foregroundStyle(.secondary)
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
        trendsQuestionsEnabled = false
        appReviewManager.hasOptedOutOfReviews = false

        // Reset import behavior
        importSettingsDefaultBehavior = "keep"

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
    @Environment(\.fontFamily) private var fontFamily
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
                    .font(.customFont(fontFamily, style: .callout, weight: .medium))
                    .frame(width: iconSize, height: iconSize)
                    .foregroundStyle(.accent)

                VStack(alignment: .leading, spacing: stackItemSpacing) {
                    Text(title)
                        .font(.customFont(fontFamily, style: .body, weight: .medium))

                    Text(subtitle)
                        .font(.customFont(fontFamily, style: .caption))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Toggle("", isOn: $isOn)
                    .labelsHidden()
                    .onChange(of: isOn) { _, newValue in
                        onChange(newValue)
                    }
            }

            Text(detail)
                .font(.customFont(fontFamily, style: .caption))
                .foregroundStyle(.secondary)
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

// MARK: - Preview

#Preview {
    NavigationView {
        AppPreferencesView()
    }
}
