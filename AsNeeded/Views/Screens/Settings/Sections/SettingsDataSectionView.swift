import SwiftUI
import SFSafeSymbols

struct SettingsDataSectionView: View {
	@Environment(\.fontFamily) private var fontFamily
	private let itemSpacing: CGFloat = 16
	private let headerSpacing: CGFloat = 12

	var body: some View {
		VStack(alignment: .leading, spacing: itemSpacing) {
			Text("Data & Privacy")
				.font(.customFont(fontFamily, style: .title2, weight: .semibold))
				.accessibilityAddTraits(.isHeader)

			NavigationLink {
				DataPrivacyView()
			} label: {
				SettingsNavigationRowLabel(
					title: "Data & Privacy",
					subtitle: "Backup, export, import, and privacy choices",
					icon: .lockShield,
					iconColor: .accent
				)
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

/// Shared settings labels keep layout chrome fixed and give enlarged text the full row width.
struct SettingsNavigationRowLabel: View {
	@Environment(\.fontFamily) private var fontFamily
	@Environment(\.dynamicTypeSize) private var dynamicTypeSize
	let title: String
	let subtitle: String
	let icon: SFSymbol
	var iconColor: Color = .accent

	var body: some View {
		HStack(alignment: .center, spacing: 12) {
			if !dynamicTypeSize.isAccessibilitySize {
				Image(systemSymbol: icon)
					.font(.system(size: 22, weight: .medium))
					.frame(width: 24, height: 24)
					.foregroundStyle(iconColor)
					.accessibilityHidden(true)
			}

			VStack(alignment: .leading, spacing: 4) {
				Text(title)
					.font(.customFont(fontFamily, style: .body, weight: .medium))
					.foregroundStyle(.primary)
					.fixedSize(horizontal: false, vertical: true)
				Text(subtitle)
					.font(.customFont(fontFamily, style: .caption))
					.foregroundStyle(.secondary)
					.fixedSize(horizontal: false, vertical: true)
			}
			.frame(maxWidth: .infinity, alignment: .leading)
			.layoutPriority(1)

			if !dynamicTypeSize.isAccessibilitySize {
				Image(systemSymbol: .chevronRight)
					.font(.system(size: 12, weight: .medium))
					.foregroundStyle(.secondary)
					.accessibilityHidden(true)
			}
		}
		.padding(16)
		.frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
		.background(Color(.systemBackground))
		.clipShape(RoundedRectangle(cornerRadius: 12))
		.overlay {
			RoundedRectangle(cornerRadius: 12)
				.stroke(Color(.systemGray4), lineWidth: 0.5)
		}
		.contentShape(Rectangle())
		.accessibilityElement(children: .combine)
		.accessibilityLabel(title)
		.accessibilityHint(subtitle)
	}
}
