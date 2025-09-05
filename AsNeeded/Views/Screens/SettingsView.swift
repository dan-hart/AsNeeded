import SwiftUI

struct SettingsView: View {
  var body: some View {
	NavigationView {
	  ScrollView {
		VStack(alignment: .leading, spacing: 32) {
		  Text("Settings")
			.font(.largeTitle)
			.fontWeight(.semibold)
			.padding(.bottom, 4)
		  
		  VStack(alignment: .leading, spacing: 16) {
			MedicalDisclaimerView()
			
			FeedbackButtonsView()
		  }
		  
		  SettingsNotificationSectionView()
		  
		  SettingsDataSectionView()

		  SettingsSupportSectionView()

		  SettingsAboutSectionView()

		  Spacer(minLength: 32)
		}
		.padding(.horizontal)
		.padding(.vertical)
	  }
	}
  }
}

#if DEBUG
#Preview {
	SettingsView()
}
#endif
