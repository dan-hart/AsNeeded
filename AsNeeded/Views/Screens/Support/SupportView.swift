import SwiftUI
import SFSafeSymbols
import DHLoggingKit
import SafariServices

struct SupportView: View {
	@ScaledMetric private var spacing24: CGFloat = 24
	@ScaledMetric private var spacing20: CGFloat = 20
	@ScaledMetric private var spacing16: CGFloat = 16
	@ScaledMetric private var spacing12: CGFloat = 12
	@ScaledMetric private var spacing8: CGFloat = 8
	@ScaledMetric private var spacing6: CGFloat = 6
	@ScaledMetric private var spacing4: CGFloat = 4
	@ScaledMetric private var spacing2: CGFloat = 2
	@ScaledMetric private var padding20: CGFloat = 20
	@ScaledMetric private var padding16: CGFloat = 16
	@ScaledMetric private var padding12: CGFloat = 12
	@ScaledMetric private var padding8: CGFloat = 8
	@ScaledMetric private var padding4: CGFloat = 4
	@ScaledMetric private var cornerRadius12: CGFloat = 12
	@ScaledMetric private var cornerRadius10: CGFloat = 10
	@ScaledMetric private var lineWidth1: CGFloat = 1
	@ScaledMetric private var minHeight100: CGFloat = 100

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
			VStack(alignment: .leading, spacing: spacing24) {
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
							.cornerRadius(cornerRadius12)
					}
			}
		}
	}
	
	private var headerSection: some View {
		VStack(alignment: .center, spacing: spacing16) {
			VStack(spacing: spacing8) {
				HStack(spacing: spacing8) {
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
		.padding(.vertical, padding8)
	}
	
	private var supportOptionsSection: some View {
		VStack(alignment: .leading, spacing: spacing20) {
			// Support Section
			VStack(alignment: .leading, spacing: spacing16) {
				Text("Support Development")
					.font(.customFont(fontFamily, style: .title2, weight: .semibold))

				// Tip Jar
				tipJarGrid

				// Rate & Review CTA (between tips and subscriptions)
				if ReviewService.shared.canShowReviewButtons {
					rateAndReviewButton
				}

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
		VStack(alignment: .leading, spacing: spacing16) {
			Text("Open Source & Free")
				.font(.customFont(fontFamily, style: .title2, weight: .semibold))

			VStack(alignment: .leading, spacing: spacing12) {
				Text("As Needed will always be free with all features available. No ads, no premium tiers, no subscriptions required. The app is open source - you can inspect the code or contribute improvements.")
					.font(.body)
					.foregroundStyle(.secondary)

				Button {
					if let url = URL(string: "https://github.com/dan-hart/AsNeeded") {
						openURL(url)
					}
				} label: {
					HStack(spacing: spacing12) {
						Image(systemSymbol: .chevronLeftForwardslashChevronRight)
							.font(.title3)
							.foregroundColor(.primary)

						VStack(alignment: .leading, spacing: spacing2) {
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
					.padding(padding16)
					.background(.regularMaterial)
					.cornerRadius(cornerRadius12)
				}
				.buttonStyle(.plain)
			}
		}
	}

	private var testFlightSection: some View {
		VStack(alignment: .leading, spacing: spacing16) {
			Text("Beta Testing")
				.font(.customFont(fontFamily, style: .title2, weight: .semibold))

			TestFlightAccessComponent()
		}
	}

	private var rateAndReviewButton: some View {
		Button {
			ReviewService.shared.openAppStoreReviewPage()
		} label: {
			HStack(spacing: spacing12) {
				Image(systemSymbol: .star)
					.font(.title3)
					.foregroundColor(.accent)

				VStack(alignment: .leading, spacing: spacing2) {
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
			.padding(padding16)
			.background(.regularMaterial)
			.cornerRadius(cornerRadius12)
		}
		.buttonStyle(.plain)
		.padding(.top, padding8)
	}

	private var tipJarGrid: some View {
		VStack(alignment: .leading, spacing: spacing12) {
			Text("One-time Tips")
				.font(.headline)
				.fontWeight(.semibold)
				.padding(.top, padding8)

			LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: spacing12) {
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
		VStack(alignment: .leading, spacing: spacing12) {
			Text("Monthly Auto-Renewable Subscriptions")
				.font(.headline)
				.fontWeight(.semibold)
				.padding(.top, padding8)

			Text("Ongoing monthly support for development • Cancel anytime in Settings")
				.font(.caption)
				.foregroundColor(.secondary)

			VStack(spacing: spacing8) {
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
			.padding(.horizontal, padding20)
			.padding(.vertical, padding12)
			.background(
				RoundedRectangle(cornerRadius: cornerRadius10)
                    .fill(.accent)
			)
		}
		.buttonStyle(.plain)
		.padding(.top, padding16)
	}
	
	private var legalLinksSection: some View {
        VStack(alignment: .leading, spacing: spacing8) {
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
		.padding(.top, padding4)
	}
	
	private var subscriptionLegalInfo: some View {
		VStack(alignment: .leading, spacing: spacing6) {
			Text("Subscription automatically renews monthly unless canceled. Manage in Settings > Apple ID > Subscriptions.")
				.font(.caption2)
				.foregroundColor(.secondary)
				.padding(.top, padding8)
		}
		.padding(.horizontal, padding4)
	}
	
	private let tipTiers = [
		(title: "Thanks", emoji: "👍", color: Color.green, price: "$0.99", productId: RevenueCatManager.ProductIdentifier.tipThanks),
		(title: "Cheers", emoji: "🥂", color: Color.orange, price: "$2.99", productId: RevenueCatManager.ProductIdentifier.tipCheers),
		(title: "Ovation", emoji: "👏", color: Color.purple, price: "$4.99", productId: RevenueCatManager.ProductIdentifier.tipOvation)
	]
	
	private let subscriptionTiers = [
		(title: "Supporter", description: "Basic monthly support", icon: SFSymbol.heart, color: Color.accentColor, price: "$1.99", productId: RevenueCatManager.ProductIdentifier.subscriptionSupporter),
		(title: "Advocate", description: "Enhanced monthly support", icon: SFSymbol.handRaisedFill, color: Color.green, price: "$4.99", productId: RevenueCatManager.ProductIdentifier.subscriptionAdvocate),
		(title: "Champion", description: "Premium monthly support", icon: SFSymbol.crownFill, color: Color.purple, price: "$9.99", productId: RevenueCatManager.ProductIdentifier.subscriptionChampion)
	]
}


// MARK: - Tip Button
private struct TipButton: View {
	@ScaledMetric private var spacing8: CGFloat = 8
	@ScaledMetric private var padding16: CGFloat = 16
	@ScaledMetric private var padding8: CGFloat = 8
	@ScaledMetric private var cornerRadius12: CGFloat = 12
	@ScaledMetric private var lineWidth1: CGFloat = 1
	@ScaledMetric private var minHeight100: CGFloat = 100

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
			VStack(spacing: spacing8) {
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
			.frame(maxWidth: .infinity, minHeight: minHeight100)
			.padding(.vertical, padding16)
			.padding(.horizontal, padding8)
			.background(tip.color.opacity(0.1))
			.overlay(
				RoundedRectangle(cornerRadius: cornerRadius12)
					.stroke(tip.color, lineWidth: lineWidth1)
			)
			.cornerRadius(cornerRadius12)
		}
		.buttonStyle(.plain)
	}
}


// MARK: - Subscription Button
private struct SubscriptionButton: View {
	@ScaledMetric private var spacing12: CGFloat = 12
	@ScaledMetric private var spacing2: CGFloat = 2
	@ScaledMetric private var padding16: CGFloat = 16
	@ScaledMetric private var cornerRadius12: CGFloat = 12
	@ScaledMetric private var lineWidth1: CGFloat = 1
	@ScaledMetric private var iconSize24: CGFloat = 24

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
			HStack(spacing: spacing12) {
				Image(systemSymbol: subscription.icon)
					.font(.callout.weight(.medium))
					.frame(width: iconSize24, height: iconSize24)
					.foregroundColor(subscription.color)

				VStack(alignment: .leading, spacing: spacing2) {
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
			.padding(padding16)
			.background(Color(.systemBackground))
			.overlay(
				RoundedRectangle(cornerRadius: cornerRadius12)
					.stroke(subscription.color, lineWidth: lineWidth1)
			)
			.cornerRadius(cornerRadius12)
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
