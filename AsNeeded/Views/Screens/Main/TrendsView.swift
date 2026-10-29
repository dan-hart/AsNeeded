// Create a new SwiftUI file for the Trends tab.
// This is a placeholder for the TrendsView, following best practices for reusable components.

import SwiftUI

struct TrendsView: View {
    @EnvironmentObject private var navigationManager: NavigationManager

    var body: some View {
        MedicationTrendsView(widgetScope: navigationManager.widgetTrendsScope)
			.id(navigationManager.widgetTrendsScope)
            .environmentObject(navigationManager)
    }
}

#if DEBUG
    #Preview {
        TrendsView()
    }
#endif
