import SwiftUI

struct SettingsView: View {
  var body: some View {
	NavigationView {
	  ScrollView {
		VStack(alignment: .leading, spacing: 32) {
		  SettingsNotificationSectionView()
		  
		  SettingsFeedbackSectionView()
		  
		  SettingsDataSectionView()

		  SettingsSupportSectionView()

		  SettingsAboutSectionView()
		  
		  SettingsDisclaimersSectionView()

		  Spacer(minLength: 32)
		}
		.padding(.horizontal)
		.padding(.vertical)
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
