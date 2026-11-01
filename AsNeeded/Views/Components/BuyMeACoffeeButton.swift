import SFSafeSymbols
import SwiftUI

struct BuyMeACoffeeButton: View {
	@Environment(\.openURL) private var openURL
	@Environment(\.fontFamily) private var fontFamily
	@ScaledMetric private var rowSpacing: CGFloat = 12
	@ScaledMetric private var labelSpacing: CGFloat = 2
	@ScaledMetric private var cardPadding: CGFloat = 16
	@ScaledMetric private var cardCornerRadius: CGFloat = 12
	@ScaledMetric private var headerPaddingV: CGFloat = 8

	var title: LocalizedStringKey = "Buy Me a Coffee"
	var subtitle: LocalizedStringKey = "Support development with a coffee"

	var body: some View {
		Button {
			if let url = AppURLs.buyMeACoffee {
				openURL(url)
			}
		} label: {
			HStack(spacing: rowSpacing) {
				Image(systemSymbol: .cupAndSaucerFill)
					.font(.customFont(fontFamily, style: .title3))
					.foregroundStyle(.orange)
					.accessibilityHidden(true)

				VStack(alignment: .leading, spacing: labelSpacing) {
					Text(title)
						.font(.customFont(fontFamily, style: .headline, weight: .semibold))
						.foregroundStyle(.primary)
					Text(subtitle)
						.font(.customFont(fontFamily, style: .subheadline))
						.foregroundStyle(.secondary)
				}
				.fixedSize(horizontal: false, vertical: true)
				.frame(maxWidth: .infinity, alignment: .leading)

				Image(systemSymbol: .arrowUpRight)
					.font(.customFont(fontFamily, style: .caption))
					.foregroundStyle(.secondary)
					.accessibilityHidden(true)
			}
			.padding(cardPadding)
			.frame(maxWidth: .infinity, minHeight: 44)
			.background(.regularMaterial, in: RoundedRectangle(cornerRadius: cardCornerRadius))
		}
		.buttonStyle(.plain)
		.padding(.top, headerPaddingV)
	}
}
