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
          
          medicalDisclaimerSection
          
          dataSection
          
          Spacer(minLength: 32)
        }
        .padding()
      }
    }
  }
  
  private var dataSection: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("Data")
        .font(.title2)
        .fontWeight(.semibold)
      
      DataManagementView()
    }
  }
  
  private var medicalDisclaimerSection: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("Important Information")
        .font(.title2)
        .fontWeight(.semibold)
      
      MedicalDisclaimerView()
    }
  }
}

#if DEBUG
#Preview {
    SettingsView()
}
#endif
