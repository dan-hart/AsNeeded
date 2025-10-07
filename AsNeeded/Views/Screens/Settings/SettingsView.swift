import SwiftUI

struct SettingsView: View {
	@ScaledMetric private var sectionSpacing: CGFloat = 32
	@ScaledMetric private var padding: CGFloat = 16

	var body: some View {
		NavigationView {
			ScrollView {
				VStack(alignment: .leading, spacing: sectionSpacing) {
					SettingsSupportSectionView()

					SettingsFeedbackSectionView()

					SettingsHealthKitSectionView()

					SettingsDataSectionView()

					SettingsAboutSectionView()

					SettingsPreferencesSectionView()

					SettingsDisclaimersSectionView()

#if DEBUG
					SettingsDebugSectionView()
#endif

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
