import SwiftUI
import SFSafeSymbols

struct SettingsRowComponent: View {
	let icon: SFSymbol
	let title: String
	let subtitle: String
	let iconColor: Color
	let action: () -> Void

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
			HStack(spacing: 12) {
				Image(systemSymbol: icon)
					.font(.callout.weight(.medium))
					.frame(width: 24, height: 24)
					.foregroundColor(iconColor)

				VStack(alignment: .leading, spacing: 2) {
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