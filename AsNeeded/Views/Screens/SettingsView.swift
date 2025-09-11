import SwiftUI

struct SettingsView: View {
  var body: some View {
	NavigationView {
	  ScrollView {
		VStack(alignment: .leading, spacing: 32) {
          SettingsSupportSectionView()
            
		  SettingsNotificationSectionView()
		  
		  SettingsHapticsSectionView()
		  
		  SettingsFeedbackSectionView()
		  
		  SettingsDataSectionView()

		  SettingsAboutSectionView()
		  
		  SettingsDisclaimersSectionView()
		  
#if DEBUG
		  SettingsDebugSectionView()
#endif

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
