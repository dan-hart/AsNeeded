import SwiftUI
import SFSafeSymbols
import DHLoggingKit
import SafariServices

struct SupportView: View {
	@Environment(\.openURL) private var openURL
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
		NavigationView {
			ScrollView {
				VStack(alignment: .leading, spacing: 24) {
					headerSection
					
					supportOptionsSection
					
					aboutOpenSourceSection
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
								.cornerRadius(12)
						}
				}
			}
		}
	}
	
	private var headerSection: some View {
		VStack(alignment: .center, spacing: 16) {
			VStack(spacing: 8) {
				HStack(spacing: 8) {
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
		.padding(.vertical, 8)
	}
	
	private var supportOptionsSection: some View {
		VStack(alignment: .leading, spacing: 20) {
			// Support Section
			VStack(alignment: .leading, spacing: 16) {
				Text("Support Development")
					.font(.title2)
					.fontWeight(.semibold)

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
		VStack(alignment: .leading, spacing: 16) {
			Text("Open Source & Free")
				.font(.title2)
				.fontWeight(.semibold)
			
			VStack(alignment: .leading, spacing: 12) {
				Text("As Needed will always be free with all features available. No ads, no premium tiers, no subscriptions required. The app is open source - you can inspect the code or contribute improvements.")
					.font(.body)
					.foregroundStyle(.secondary)

				Button {
					if let url = URL(string: "https://github.com/dan-hart/AsNeeded") {
						openURL(url)
					}
				} label: {
					HStack(spacing: 12) {
						Image(systemSymbol: .chevronLeftForwardslashChevronRight)
							.font(.title3)
							.foregroundColor(.primary)

						VStack(alignment: .leading, spacing: 2) {
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
					.padding(16)
					.background(.regularMaterial)
					.cornerRadius(12)
				}
				.buttonStyle(.plain)
			}
		}
	}

	private var rateAndReviewButton: some View {
		Button {
			ReviewService.shared.openAppStoreReviewPage()
		} label: {
			HStack(spacing: 12) {
				Image(systemSymbol: .star)
					.font(.title3)
					.foregroundColor(.accent)

				VStack(alignment: .leading, spacing: 2) {
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
			.padding(16)
			.background(.regularMaterial)
			.cornerRadius(12)
		}
		.buttonStyle(.plain)
		.padding(.top, 8)
	}

	private var tipJarGrid: some View {
		VStack(alignment: .leading, spacing: 12) {
			Text("One-time Tips")
				.font(.headline)
				.fontWeight(.semibold)
				.padding(.top, 8)
			
			LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
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
		VStack(alignment: .leading, spacing: 12) {
			Text("Monthly Auto-Renewable Subscriptions")
				.font(.headline)
				.fontWeight(.semibold)
				.padding(.top, 8)
			
			Text("Ongoing monthly support for development • Cancel anytime in Settings")
				.font(.caption)
				.foregroundColor(.secondary)
			
			VStack(spacing: 8) {
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
			.padding(.horizontal, 20)
			.padding(.vertical, 12)
			.background(
				RoundedRectangle(cornerRadius: 10)
                    .fill(.accent)
			)
		}
		.buttonStyle(.plain)
		.padding(.top, 16)
	}
	
	private var legalLinksSection: some View {
        VStack(alignment: .leading, spacing: 8) {
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
		.padding(.top, 4)
	}
	
	private var subscriptionLegalInfo: some View {
		VStack(alignment: .leading, spacing: 6) {
			Text("Subscription automatically renews monthly unless canceled. Manage in Settings > Apple ID > Subscriptions.")
				.font(.caption2)
				.foregroundColor(.secondary)
				.padding(.top, 8)
		}
		.padding(.horizontal, 4)
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
			VStack(spacing: 8) {
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
			.frame(maxWidth: .infinity, minHeight: 100)
			.padding(.vertical, 16)
			.padding(.horizontal, 8)
			.background(tip.color.opacity(0.1))
			.overlay(
				RoundedRectangle(cornerRadius: 12)
					.stroke(tip.color, lineWidth: 1)
			)
			.cornerRadius(12)
		}
		.buttonStyle(.plain)
	}
}


// MARK: - Subscription Button
private struct SubscriptionButton: View {
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
			HStack(spacing: 12) {
				Image(systemSymbol: subscription.icon)
					.font(.system(size: 18, weight: .medium))
					.frame(width: 24, height: 24)
					.foregroundColor(subscription.color)
				
				VStack(alignment: .leading, spacing: 2) {
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
			.padding(16)
			.background(Color(.systemBackground))
			.overlay(
				RoundedRectangle(cornerRadius: 12)
					.stroke(subscription.color, lineWidth: 1)
			)
			.cornerRadius(12)
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
