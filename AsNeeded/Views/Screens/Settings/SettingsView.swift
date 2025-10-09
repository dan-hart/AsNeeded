import SwiftUI

struct SettingsView: View {
	@StateObject private var featureToggleManager = FeatureToggleManager.shared
	@ScaledMetric private var sectionSpacing: CGFloat = 24
	@ScaledMetric private var padding: CGFloat = 16

	var body: some View {
		NavigationView {
			ScrollView {
				VStack(alignment: .leading, spacing: sectionSpacing) {
					SettingsSupportSectionView()

					SettingsFeedbackSectionView()

					SettingsDataSectionView()

					SettingsAboutSectionView()

					SettingsPreferencesSectionView()

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
			.navigationTitle("Settings")
			.navigationBarTitleDisplayMode(.large)
		}
	}
}

#if DEBUG
#Preview {
	SettingsView()
}
#endif
