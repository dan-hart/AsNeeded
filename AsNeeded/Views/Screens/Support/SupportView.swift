import SwiftUI
import SFSafeSymbols
import DHLoggingKit
import SafariServices

struct SupportView: View {
	@ScaledMetric private var sectionSpacing: CGFloat = 24
	@ScaledMetric private var subsectionSpacing: CGFloat = 20
	@ScaledMetric private var itemSpacing: CGFloat = 16
	@ScaledMetric private var rowSpacing: CGFloat = 12
	@ScaledMetric private var compactSpacing: CGFloat = 8
	@ScaledMetric private var legalLinksSpacing: CGFloat = 6
	@ScaledMetric private var subscriptionInfoSpacing: CGFloat = 4
	@ScaledMetric private var labelSpacing: CGFloat = 2
	@ScaledMetric private var restoreButtonPaddingH: CGFloat = 20
	@ScaledMetric private var cardPadding: CGFloat = 16
	@ScaledMetric private var buttonPaddingV: CGFloat = 12
	@ScaledMetric private var headerPaddingV: CGFloat = 8
	@ScaledMetric private var legalLinksPaddingTop: CGFloat = 4
	@ScaledMetric private var cardCornerRadius: CGFloat = 12
	@ScaledMetric private var buttonCornerRadius: CGFloat = 10
	@ScaledMetric private var borderWidth: CGFloat = 1
	@ScaledMetric private var tipButtonMinHeight: CGFloat = 100

	@Environment(\.openURL) private var openURL
	@Environment(\.fontFamily) private var fontFamily
	@EnvironmentObject private var revenueCatManager: RevenueCatManager
	@State private var isPurchasing = false
	@State private var showPurchaseAlert = false
	@State private var alertTitle = ""
	@State private var alertMessage = ""
	@State private var showThankYouView = false
	@State private var purchaseType: ThankYouView.PurchaseType?
	@State private var showingWebView = false
	@State private var webURL: URL?
	
	var body: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: sectionSpacing) {
				headerSection

				supportOptionsSection

				aboutOpenSourceSection

				testFlightSection
			}
			.padding(.horizontal)
			.padding(.vertical)
		}
		.navigationTitle("Support")
		.navigationBarTitleDisplayMode(.large)
		.alert(alertTitle, isPresented: $showPurchaseAlert) {
			Button("OK", role: .cancel) {}
		} message: {
			Text(alertMessage)
		}
		.sheet(isPresented: $showThankYouView) {
			if let purchaseType = purchaseType {
				ThankYouView(purchaseType: purchaseType)
					.environmentObject(FeedbackService.shared)
			}
		}
		.sheet(isPresented: $showingWebView) {
			if let url = webURL {
				SafariView(url: url)
			}
		}
		.disabled(isPurchasing)
		.overlay {
			if isPurchasing {
				Color.black.opacity(0.3)
					.ignoresSafeArea()
					.overlay {
						ProgressView("Processing...")
							.padding()
							.background(.regularMaterial)
							.cornerRadius(cardCornerRadius)
					}
			}
		}
	}
	
	private var headerSection: some View {
		VStack(alignment: .center, spacing: itemSpacing) {
			VStack(spacing: compactSpacing) {
				HStack(spacing: compactSpacing) {
					Image(systemSymbol: .heart)
						.font(.title2)
						.foregroundColor(.red)
					Text("Support As Needed")
						.font(.title)
						.fontWeight(.semibold)
				}

				Text("Help keep this app free, open source, and privacy-focused")
					.font(.subheadline)
					.foregroundColor(.secondary)
					.multilineTextAlignment(.center)
			}
		}
		.frame(maxWidth: .infinity)
		.padding(.vertical, headerPaddingV)
	}
	
	private var supportOptionsSection: some View {
		VStack(alignment: .leading, spacing: subsectionSpacing) {
			// Support Section
			VStack(alignment: .leading, spacing: itemSpacing) {
				Text("Support Development")
					.font(.customFont(fontFamily, style: .title2, weight: .semibold))

				// Tip Jar
				tipJarGrid

				// Rate & Review CTA (between tips and subscriptions)
				rateAndReviewButton

				// Subscription Options
				subscriptionOptions

				// Restore Purchases button
				restorePurchasesButton

				// Legal links for subscriptions
				legalLinksSection
			}
		}
	}
	
	private var aboutOpenSourceSection: some View {
		VStack(alignment: .leading, spacing: itemSpacing) {
			Text("Open Source & Free")
				.font(.customFont(fontFamily, style: .title2, weight: .semibold))

			VStack(alignment: .leading, spacing: rowSpacing) {
				Text("As Needed will always be free with all features available. No ads, no premium tiers, no subscriptions required. The app is open source - you can inspect the code or contribute improvements.")
					.font(.body)
					.foregroundStyle(.secondary)

				Button {
					if let url = URL(string: "https://github.com/dan-hart/AsNeeded") {
						openURL(url)
					}
				} label: {
					HStack(spacing: rowSpacing) {
						Image(systemSymbol: .chevronLeftForwardslashChevronRight)
							.font(.title3)
							.foregroundColor(.primary)

						VStack(alignment: .leading, spacing: labelSpacing) {
							Text("Contribute on GitHub")
								.font(.headline)
								.fontWeight(.semibold)
								.foregroundColor(.primary)

							Text("View source code, report issues, or contribute")
								.font(.subheadline)
								.foregroundColor(.secondary)
						}

						Spacer()

						Image(systemSymbol: .arrowUpRight)
							.font(.caption)
							.foregroundColor(.secondary)
					}
					.padding(cardPadding)
					.background(.regularMaterial)
					.cornerRadius(cardCornerRadius)
				}
				.buttonStyle(.plain)
			}
		}
	}

	private var testFlightSection: some View {
		VStack(alignment: .leading, spacing: itemSpacing) {
			Text("Beta Testing")
				.font(.customFont(fontFamily, style: .title2, weight: .semibold))

			TestFlightAccessComponent()
		}
	}

	private var rateAndReviewButton: some View {
		Button {
			ReviewService.shared.openAppStoreReviewPage()
		} label: {
			HStack(spacing: rowSpacing) {
				Image(systemSymbol: .star)
					.font(.title3)
					.foregroundColor(.accent)

				VStack(alignment: .leading, spacing: labelSpacing) {
					Text("Rate & Review on App Store")
						.font(.headline)
						.fontWeight(.semibold)
						.foregroundColor(.primary)

					Text("Share your experience and help others discover the app")
						.font(.subheadline)
						.foregroundColor(.secondary)
				}

				Spacer()

				Image(systemSymbol: .arrowUpRight)
					.font(.caption)
					.foregroundColor(.secondary)
			}
			.padding(cardPadding)
			.background(.regularMaterial)
			.cornerRadius(cardCornerRadius)
		}
		.buttonStyle(.plain)
		.padding(.top, headerPaddingV)
	}

	private var tipJarGrid: some View {
		VStack(alignment: .leading, spacing: rowSpacing) {
			Text("One-time Tips")
				.font(.headline)
				.fontWeight(.semibold)
				.padding(.top, headerPaddingV)

			LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: rowSpacing) {
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
	
	private var subscriptionOptions: some View {
		VStack(alignment: .leading, spacing: rowSpacing) {
			Text("Monthly Auto-Renewable Subscriptions")
				.font(.headline)
				.fontWeight(.semibold)
				.padding(.top, headerPaddingV)

			Text("Ongoing monthly support for development • Cancel anytime in Settings")
				.font(.caption)
				.foregroundColor(.secondary)

			VStack(spacing: compactSpacing) {
				ForEach(subscriptionTiers, id: \.title) { subscription in
					SubscriptionButton(subscription: subscription,
									  isPurchasing: $isPurchasing,
									  showPurchaseAlert: $showPurchaseAlert,
									  alertTitle: $alertTitle,
									  alertMessage: $alertMessage,
									  showThankYouView: $showThankYouView,
									  purchaseType: $purchaseType)
				}
			}

			// Required legal information for subscriptions
			subscriptionLegalInfo
		}
	}
	
	private var restorePurchasesButton: some View {
		Button {
			Task {
				isPurchasing = true
				defer { isPurchasing = false }

				let success = await revenueCatManager.restorePurchases()

				if success {
					alertTitle = "Restore Complete"
					alertMessage = "Your purchases have been restored successfully."
				} else {
					alertTitle = "Restore Failed"
					alertMessage = revenueCatManager.purchaseError ?? "Unable to restore purchases. Please try again later."
				}

				showPurchaseAlert = true
			}
		} label: {
			HStack {
				Image(systemSymbol: .arrowClockwise)
					.font(.callout)
				Text("Restore Purchases")
					.font(.callout)
					.fontWeight(.medium)
			}
			.foregroundColor(.white)
			.padding(.horizontal, restoreButtonPaddingH)
			.padding(.vertical, buttonPaddingV)
			.background(
				RoundedRectangle(cornerRadius: buttonCornerRadius)
                    .fill(.accent)
			)
		}
		.buttonStyle(.plain)
		.padding(.top, cardPadding)
	}
	
	private var legalLinksSection: some View {
        VStack(alignment: .leading, spacing: compactSpacing) {
			Button {
				if let url = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/") {
					webURL = url
					showingWebView = true
				}
			} label: {
				Text("Terms of Use (EULA)")
					.font(.caption)
					.foregroundColor(.accentColor)
			}

			Button {
				if let url = URL(string: "https://github.com/dan-hart/AsNeeded/blob/develop/PRIVACY.md") {
					webURL = url
					showingWebView = true
				}
			} label: {
				Text("Privacy Policy")
					.font(.caption)
					.foregroundColor(.accentColor)
			}
		}
		.padding(.top, legalLinksPaddingTop)
	}
	
	private var subscriptionLegalInfo: some View {
		VStack(alignment: .leading, spacing: legalLinksSpacing) {
			Text("Subscription automatically renews monthly unless canceled. Manage in Settings > Apple ID > Subscriptions.")
				.font(.caption2)
				.foregroundColor(.secondary)
				.padding(.top, headerPaddingV)
		}
		.padding(.horizontal, subscriptionInfoSpacing)
	}
	
	private let tipTiers = [
		(title: "Thanks", emoji: "👍", color: Color.green, price: "$0.99", productId: RevenueCatManager.ProductIdentifier.tipThanks),
		(title: "Cheers", emoji: "🥂", color: Color.orange, price: "$2.99", productId: RevenueCatManager.ProductIdentifier.tipCheers),
		(title: "Ovation", emoji: "👏", color: Color.purple, price: "$4.99", productId: RevenueCatManager.ProductIdentifier.tipOvation)
	]
	
	private let subscriptionTiers = [
		(title: "Supporter", description: "Basic monthly support", icon: SFSymbol.heart, color: .accent, price: "$1.99", productId: RevenueCatManager.ProductIdentifier.subscriptionSupporter),
		(title: "Advocate", description: "Enhanced monthly support", icon: SFSymbol.handRaisedFill, color: Color.green, price: "$4.99", productId: RevenueCatManager.ProductIdentifier.subscriptionAdvocate),
		(title: "Champion", description: "Premium monthly support", icon: SFSymbol.crownFill, color: Color.purple, price: "$9.99", productId: RevenueCatManager.ProductIdentifier.subscriptionChampion)
	]
}


// MARK: - Tip Button
private struct TipButton: View {
	@ScaledMetric private var contentSpacing: CGFloat = 8
	@ScaledMetric private var paddingV: CGFloat = 16
	@ScaledMetric private var paddingH: CGFloat = 8
	@ScaledMetric private var cardCornerRadius: CGFloat = 12
	@ScaledMetric private var borderWidth: CGFloat = 1
	@ScaledMetric private var minHeight: CGFloat = 100

	let tip: (title: String, emoji: String, color: Color, price: String, productId: RevenueCatManager.ProductIdentifier)
	@EnvironmentObject private var revenueCatManager: RevenueCatManager
	@Binding var isPurchasing: Bool
	@Binding var showPurchaseAlert: Bool
	@Binding var alertTitle: String
	@Binding var alertMessage: String
	@Binding var showThankYouView: Bool
	@Binding var purchaseType: ThankYouView.PurchaseType?
	
	var body: some View {
		Button {
			Task {
				isPurchasing = true
				defer { isPurchasing = false }
				
				let success = await revenueCatManager.purchaseTip(tip.productId)
				
				if success {
					purchaseType = .tip(amount: tip.price)
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
					.font(.title2)

				Text(tip.title)
					.font(.caption)
					.fontWeight(.medium)
					.multilineTextAlignment(.center)
					.lineLimit(1)

				Text(tip.price)
					.font(.caption2)
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
	}
}


// MARK: - Subscription Button
private struct SubscriptionButton: View {
	@ScaledMetric private var contentSpacing: CGFloat = 12
	@ScaledMetric private var labelSpacing: CGFloat = 2
	@ScaledMetric private var cardPadding: CGFloat = 16
	@ScaledMetric private var cardCornerRadius: CGFloat = 12
	@ScaledMetric private var borderWidth: CGFloat = 1
	@ScaledMetric private var iconSize: CGFloat = 24

	let subscription: (title: String, description: String, icon: SFSymbol, color: Color, price: String, productId: RevenueCatManager.ProductIdentifier)
	@EnvironmentObject private var revenueCatManager: RevenueCatManager
	@Binding var isPurchasing: Bool
	@Binding var showPurchaseAlert: Bool
	@Binding var alertTitle: String
	@Binding var alertMessage: String
	@Binding var showThankYouView: Bool
	@Binding var purchaseType: ThankYouView.PurchaseType?
	
	var body: some View {
		Button {
			Task {
				isPurchasing = true
				defer { isPurchasing = false }
				
				let success = await revenueCatManager.purchaseSubscription(subscription.productId)
				
				if success {
					purchaseType = .subscription(plan: subscription.title)
					showThankYouView = true
				} else if let error = revenueCatManager.purchaseError {
					alertTitle = "Subscription Failed"
					alertMessage = error
					showPurchaseAlert = true
				}
			}
		} label: {
			HStack(spacing: contentSpacing) {
				Image(systemSymbol: subscription.icon)
					.font(.callout.weight(.medium))
					.frame(width: iconSize, height: iconSize)
					.foregroundColor(subscription.color)

				VStack(alignment: .leading, spacing: labelSpacing) {
					Text(subscription.title)
						.font(.body)
						.fontWeight(.medium)
					Text(subscription.description)
						.font(.caption)
						.foregroundColor(.secondary)
				}

				Spacer()

				Text(subscription.price + "/month")
					.font(.caption)
					.fontWeight(.medium)
					.foregroundColor(subscription.color)
			}
			.padding(cardPadding)
			.background(Color(.systemBackground))
			.overlay(
				RoundedRectangle(cornerRadius: cardCornerRadius)
					.stroke(subscription.color, lineWidth: borderWidth)
			)
			.cornerRadius(cardCornerRadius)
		}
		.buttonStyle(.plain)
	}
}

// MARK: - SafariView
struct SafariView: UIViewControllerRepresentable {
	let url: URL
	
	func makeUIViewController(context: Context) -> SFSafariViewController {
		let safariViewController = SFSafariViewController(url: url)
		return safariViewController
	}
	
	func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {
		// No updates needed
	}
}

#if DEBUG
#Preview {
	SupportView()
}
#endif
