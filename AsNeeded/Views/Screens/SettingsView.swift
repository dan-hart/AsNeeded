import SwiftUI

struct SettingsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            Text("Settings")
                .font(.largeTitle)
                .fontWeight(.semibold)
                .padding(.bottom, 4)
            MedicalDisclaimerView()
            Spacer()
        }
        .padding()
    }
}

#if DEBUG
#Preview {
    SettingsView()
}
#endif
