import SwiftUI
import SFSafeSymbols

struct SettingsDataSectionView: View {
	@Environment(\.fontFamily) private var fontFamily
	@ScaledMetric private var itemSpacing: CGFloat = 16
	@ScaledMetric private var headerSpacing: CGFloat = 12
	@ScaledMetric private var stackItemSpacing: CGFloat = 2
	@ScaledMetric private var iconSize: CGFloat = 24
	@ScaledMetric private var padding: CGFloat = 16
	@ScaledMetric private var cornerRadius: CGFloat = 12
	@ScaledMetric private var borderWidth: CGFloat = 0.5

	var body: some View {
		VStack(alignment: .leading, spacing: itemSpacing) {
			Text("Data & Privacy")
				.font(.customFont(fontFamily, style: .title2, weight: .semibold))

			NavigationLink {
				DataPrivacyView()
			} label: {
				HStack(spacing: headerSpacing) {
					Image(systemSymbol: .lockShield)
						.font(.customFont(fontFamily, style: .callout, weight: .medium))
						.frame(width: iconSize, height: iconSize)
						.foregroundColor(.accent)
						.accessibilityHidden(true)

					VStack(alignment: .leading, spacing: stackItemSpacing) {
						Text("Data & Privacy")
							.font(.customFont(fontFamily, style: .body, weight: .medium))
						Text("Backup, export, import, and privacy choices")
							.font(.customFont(fontFamily, style: .caption))
							.foregroundColor(.secondary)
							.fixedSize(horizontal: false, vertical: true)
					}

					Spacer()

					Image(systemSymbol: .chevronRight)
						.font(.customFont(fontFamily, style: .caption))
						.foregroundColor(.secondary)
						.accessibilityHidden(true)
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
			.accessibilityLabel("Data and Privacy")
			.accessibilityHint("Backup, export, import, and privacy choices")
		}
	}
}

#if DEBUG
#Preview {
  SettingsDataSectionView()
}
#endif
