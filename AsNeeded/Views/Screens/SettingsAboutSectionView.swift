import SwiftUI
import SFSafeSymbols

struct SettingsAboutSectionView: View {
  var body: some View {
	VStack(alignment: .leading, spacing: 16) {
	  Text("About")
		.font(.title2)
		.fontWeight(.semibold)

	  NavigationLink {
		AboutView()
	  } label: {
		HStack(spacing: 12) {
		  Image(systemSymbol: .infoCircle)
			.font(.system(size: 18, weight: .medium))
			.frame(width: 24, height: 24)
			.foregroundColor(.accentColor)

		  VStack(alignment: .leading, spacing: 2) {
			Text("About This App")
			  .font(.body)
			  .fontWeight(.medium)
			Text("Version, build, and overview")
			  .font(.caption)
			  .foregroundColor(.secondary)
		  }

		  Spacer()

		  Image(systemSymbol: .chevronRight)
			.font(.caption)
			.foregroundColor(.secondary)
		}
		.padding(16)
		.background(Color(.systemBackground))
		.overlay(
		  RoundedRectangle(cornerRadius: 12)
			.stroke(Color(.systemGray4), lineWidth: 0.5)
		)
		.cornerRadius(12)
	  }
	  .buttonStyle(.plain)
	}
  }
}

#if DEBUG
#Preview { SettingsAboutSectionView() }
#endif

