import SwiftUI
import SFSafeSymbols

struct SettingsDataSectionView: View {
  var body: some View {
	VStack(alignment: .leading, spacing: 16) {
	  Text("Data")
		.font(.title2)
		.fontWeight(.semibold)

	  NavigationLink {
		DataManagementView()
			  .padding()
		  .navigationTitle("Data Management")
	  } label: {
		SettingsRowComponent(
			icon: .externaldriveConnectedToLineBelow,
			title: "Data Management",
			subtitle: "Export, import, and clear your data"
		) {
			// Navigation handled by NavigationLink
		}
	  }
	}
  }
}

#if DEBUG
#Preview {
  SettingsDataSectionView()
}
#endif
