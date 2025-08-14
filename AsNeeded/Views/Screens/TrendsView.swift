// Create a new SwiftUI file for the Trends tab.
// This is a placeholder for the TrendsView, following best practices for reusable components.

import SwiftUI

struct TrendsView: View {
    var body: some View {
        MedicationTrendsView()
            .padding()
    }
}

#if DEBUG
#Preview {
    TrendsView()
}
#endif
