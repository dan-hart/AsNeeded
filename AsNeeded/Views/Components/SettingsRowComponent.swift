import SwiftUI
import SFSafeSymbols

struct SettingsRowComponent: View {
	let icon: SFSymbol
	let title: String
	let subtitle: String
	let iconColor: Color
	let action: () -> Void
	@ScaledMetric private var rowSpacing: CGFloat = 12
	@ScaledMetric private var iconSize: CGFloat = 24
	@ScaledMetric private var textSpacing: CGFloat = 2
	@ScaledMetric private var rowPadding: CGFloat = 16
	@ScaledMetric private var cornerRadius: CGFloat = 12
	@ScaledMetric private var borderWidth: CGFloat = 0.5

	init(
		icon: SFSymbol,
		title: String,
		subtitle: String,
		iconColor: Color = .accentColor,
		action: @escaping () -> Void
	) {
		self.icon = icon
		self.title = title
		self.subtitle = subtitle
		self.iconColor = iconColor
		self.action = action
	}

	var body: some View {
		Button(action: action) {
			HStack(spacing: rowSpacing) {
				Image(systemSymbol: icon)
					.font(.callout.weight(.medium))
					.frame(width: iconSize, height: iconSize)
					.foregroundColor(iconColor)

				VStack(alignment: .leading, spacing: textSpacing) {
					Text(title)
						.font(.body)
						.fontWeight(.medium)
					Text(subtitle)
						.font(.caption)
						.foregroundColor(.secondary)
				}

				Spacer()

				Image(systemSymbol: .chevronRight)
					.font(.caption)
					.foregroundColor(.secondary)
			}
			.padding(rowPadding)
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

#if DEBUG
#Preview {
	VStack(spacing: 16) {
		SettingsRowComponent(
			icon: .externaldriveConnectedToLineBelow,
			title: "Data Management",
			subtitle: "Export, import, and clear your data"
		) {
			print("Data Management tapped")
		}

		SettingsRowComponent(
			icon: .infoCircle,
			title: "About",
			subtitle: "Version info and acknowledgments",
			iconColor: .blue
		) {
			print("About tapped")
		}
	}
	.padding()
}
#endif