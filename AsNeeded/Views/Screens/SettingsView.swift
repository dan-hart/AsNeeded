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
            Text("Important Information")
              .font(.title2)
              .fontWeight(.semibold)
            MedicalDisclaimerView()
          }
          
          SettingsDataSectionView()

          SettingsAboutSectionView()

          Spacer(minLength: 32)
        }
        .padding()
      }
    }
  }
}

#if DEBUG
#Preview {
    SettingsView()
}
#endif
