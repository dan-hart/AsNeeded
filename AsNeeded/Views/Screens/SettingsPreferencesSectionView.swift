import SwiftUI
import SFSafeSymbols

struct SettingsPreferencesSectionView: View {
	var body: some View {
		VStack(alignment: .leading, spacing: 16) {
			Text("Preferences")
				.font(.title2)
				.fontWeight(.semibold)

			NavigationLink {
				AppPreferencesView()
			} label: {
				HStack(spacing: 12) {
					Image(systemSymbol: .gearshape)
						.font(.system(.callout, design: .default, weight: .medium))
						.frame(width: 24, height: 24)
						.foregroundColor(.accentColor)

					VStack(alignment: .leading, spacing: 2) {
						Text("App Preferences")
							.font(.body)
							.fontWeight(.medium)
						Text("Notifications, haptics, and app behavior")
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

#Preview {
	SettingsPreferencesSectionView()
		.padding()
}