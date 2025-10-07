import SwiftUI
import SFSafeSymbols

struct SettingsPreferencesSectionView: View {
	@ScaledMetric private var itemSpacing: CGFloat = 16
	@ScaledMetric private var headerSpacing: CGFloat = 12
	@ScaledMetric private var stackItemSpacing: CGFloat = 2
	@ScaledMetric private var iconSize: CGFloat = 24
	@ScaledMetric private var padding: CGFloat = 16
	@ScaledMetric private var cornerRadius: CGFloat = 12
	@ScaledMetric private var borderWidth: CGFloat = 0.5

	var body: some View {
		VStack(alignment: .leading, spacing: itemSpacing) {
			Text("Preferences")
				.font(.title2)
				.fontWeight(.semibold)

			NavigationLink {
				AppPreferencesView()
			} label: {
				HStack(spacing: headerSpacing) {
					Image(systemSymbol: .gearshape)
						.font(.callout.weight(.medium))
						.frame(width: iconSize, height: iconSize)
						.foregroundColor(.accent)

					VStack(alignment: .leading, spacing: stackItemSpacing) {
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
				.padding(padding)
				.background(Color(.systemBackground))
				.overlay(
					RoundedRectangle(cornerRadius: cornerRadius)
						.stroke(Color(.systemGray4), lineWidth: borderWidth)
				)
				.cornerRadius(cornerRadius)
			}
			.buttonStyle(.plain)
		}
	}
}

#Preview {
	SettingsPreferencesSectionView()
		.padding()
}