// Create a new SwiftUI file for the Medication tab.
// This is a placeholder for the MedicationView, following best practices for reusable components.

import SwiftUI

struct MedicationView: View {
    var body: some View {
        Text("Medication")
            .font(.largeTitle)
            .fontWeight(.semibold)
            .padding()
    }
}

#if DEBUG
#Preview {
    MedicationView()
}
#endif
