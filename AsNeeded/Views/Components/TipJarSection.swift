import SwiftUI

struct TipJarSection: View {
	@Environment(\.fontFamily) private var fontFamily
	@Environment(\.dynamicTypeSize) private var dynamicTypeSize
	@EnvironmentObject private var revenueCatManager: RevenueCatManager
	@ScaledMetric private var rowSpacing: CGFloat = 12
	@ScaledMetric private var headerPaddingV: CGFloat = 8

	var title: LocalizedStringKey = "One-time Tips"
	var subtitle: LocalizedStringKey? = nil
	@Binding var isPurchasing: Bool
	@Binding var showPurchaseAlert: Bool
	@Binding var alertTitle: String
	@Binding var alertMessage: String
	@Binding var showThankYouView: Bool
	@Binding var purchaseType: ThankYouView.PurchaseType?

	var body: some View {
		VStack(alignment: .leading, spacing: rowSpacing) {
			Text(title)
				.font(.customFont(fontFamily, style: .headline, weight: .semibold))
				.padding(.top, headerPaddingV)
				.accessibilityAddTraits(.isHeader)
			if let subtitle {
				Text(subtitle)
					.font(.customFont(fontFamily, style: .subheadline))
					.foregroundStyle(.secondary)
			}
			if revenueCatManager.availableProducts.isEmpty {
				Text(!revenueCatManager.isConfigured ? "Support options are not available in this build. You can keep using every feature." : (revenueCatManager.isLoadingProducts ? "Loading support options…" : "Purchase options are temporarily unavailable. You can keep using every feature."))
					.font(.customFont(fontFamily, style: .callout))
					.foregroundStyle(.secondary)
				if revenueCatManager.isConfigured && !revenueCatManager.isLoadingProducts {
					Button("Reload Prices") { Task { await revenueCatManager.reloadProducts() } }
				}
			}
			LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: dynamicTypeSize.isAccessibilitySize ? 1 : 3), spacing: rowSpacing) {
				ForEach(tipTiers, id: \.title) { tip in
					TipButton(tip: tip,
						isPurchasing: $isPurchasing,
						showPurchaseAlert: $showPurchaseAlert,
						alertTitle: $alertTitle,
						alertMessage: $alertMessage,
						showThankYouView: $showThankYouView,
						purchaseType: $purchaseType)
				}
			}
		}
	}

	private let tipTiers = [
		(title: "Thanks", emoji: "👍", color: Color.green, productId: RevenueCatManager.ProductIdentifier.tipThanks),
		(title: "Cheers", emoji: "🥂", color: Color.orange, productId: RevenueCatManager.ProductIdentifier.tipCheers),
		(title: "Ovation", emoji: "👏", color: Color.purple, productId: RevenueCatManager.ProductIdentifier.tipOvation),
	]

}

// MARK: - Tip Button
private struct TipButton: View {
	@Environment(\.fontFamily) private var fontFamily
	@ScaledMetric private var contentSpacing: CGFloat = 8
	@ScaledMetric private var paddingV: CGFloat = 16
	@ScaledMetric private var paddingH: CGFloat = 8
	@ScaledMetric private var cardCornerRadius: CGFloat = 12
	@ScaledMetric private var borderWidth: CGFloat = 1
	@ScaledMetric private var minHeight: CGFloat = 100

	let tip: (title: String, emoji: String, color: Color, productId: RevenueCatManager.ProductIdentifier)
	@EnvironmentObject private var revenueCatManager: RevenueCatManager
	@Binding var isPurchasing: Bool
	@Binding var showPurchaseAlert: Bool
	@Binding var alertTitle: String
	@Binding var alertMessage: String
	@Binding var showThankYouView: Bool
	@Binding var purchaseType: ThankYouView.PurchaseType?

	private var productPrice: String? {
		revenueCatManager.availableProducts.first { $0.productIdentifier == tip.productId.rawValue }?.localizedPriceString
	}

	var body: some View {
		Button {
			guard let displayedPrice = productPrice else { return }
			Task {
				isPurchasing = true
				defer { isPurchasing = false }

				let success = await revenueCatManager.purchaseTip(tip.productId)

				if success {
					purchaseType = .tip(amount: displayedPrice)
					showThankYouView = true
				} else if let error = revenueCatManager.purchaseError {
					alertTitle = "Purchase Failed"
					alertMessage = error
					showPurchaseAlert = true
				}
			}
		} label: {
			VStack(spacing: contentSpacing) {
				Text(tip.emoji)
					.font(.customFont(fontFamily, style: .title2))

				Text(tip.title)
					.font(.customFont(fontFamily, style: .caption))
					.fontWeight(.medium)
					.multilineTextAlignment(.center)

				Text(productPrice ?? (revenueCatManager.isLoadingProducts ? "Loading price…" : "Unavailable"))
					.font(.customFont(fontFamily, style: .caption2))
					.foregroundColor(.secondary)
			}
			.frame(maxWidth: .infinity, minHeight: minHeight)
			.padding(.vertical, paddingV)
			.padding(.horizontal, paddingH)
			.background(tip.color.opacity(0.1))
			.overlay(
				RoundedRectangle(cornerRadius: cardCornerRadius)
					.stroke(tip.color, lineWidth: borderWidth)
			)
			.cornerRadius(cardCornerRadius)
		}
		.buttonStyle(.plain)
		.disabled(productPrice == nil)
	}
}

