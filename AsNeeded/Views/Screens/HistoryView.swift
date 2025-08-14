// Create a new SwiftUI file for the History tab.
// This is a placeholder for the HistoryView, following best practices for reusable components.

import SwiftUI

struct HistoryView: View {
    var body: some View {
        Text("History")
            .font(.largeTitle)
            .fontWeight(.semibold)
            .padding()
    }
}

#if DEBUG
#Preview {
    HistoryView()
}
#endif
