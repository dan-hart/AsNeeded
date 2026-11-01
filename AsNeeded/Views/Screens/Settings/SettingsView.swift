import SwiftUI

struct SettingsView: View {
	@ObservedObject private var demoMode = DemoModeState.shared
    @StateObject private var featureToggleManager = FeatureToggleManager.shared
	private let sectionSpacing: CGFloat = 24
	private let padding: CGFloat = 16

    var body: some View {
        NavigationStack {
            VerticalOnlyScrollView {
                VStack(alignment: .leading, spacing: sectionSpacing) {
					if demoMode.isEnabled { DemoModeBanner() }
                    SettingsPreferencesSectionView()

                    SettingsDataSectionView()

                    SettingsAboutSectionView()

                    SettingsSupportSectionView()

                    SettingsFeedbackSectionView()

                    SettingsDisclaimersSectionView()

                    // Show debug section in DEBUG builds or TestFlight
                    if featureToggleManager.isFeatureToggleAvailable {
                        SettingsDebugSectionView()
                    }

                    Spacer(minLength: sectionSpacing)
                }
                .padding(.horizontal, padding)
                .padding(.vertical, padding)
            }
			.customNavigationTitle("Settings", displayMode: .large)
        }
    }
}

#if DEBUG
    #Preview {
        SettingsView()
    }
#endif
