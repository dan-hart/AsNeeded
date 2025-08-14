// Create a new SwiftUI file for the Settings tab.
// This is a placeholder for the SettingsView, following best practices for reusable components.

import SwiftUI

struct SettingsView: View {
    var body: some View {
        Text("Settings")
            .font(.largeTitle)
            .fontWeight(.semibold)
            .padding()
    }
}

#if DEBUG
#Preview {
    SettingsView()
}
#endif
