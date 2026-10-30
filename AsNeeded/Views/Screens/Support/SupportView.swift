import DHLoggingKit
import SafariServices
import SFSafeSymbols
import SwiftUI

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
        VerticalOnlyScrollView {
            VStack(alignment: .leading, spacing: sectionSpacing) {
                headerSection

                supportOptionsSection

                aboutOpenSourceSection

                testFlightSection
            }
            .padding(.horizontal)
            .padding(.vertical)
        }
		.customNavigationTitle("Support", displayMode: .large)
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
                        .font(.customFont(fontFamily, style: .title2))
                        .foregroundColor(.red)
                    Text("Support As Needed")
                        .font(.customFont(fontFamily, style: .title))
                        .fontWeight(.semibold)
                }

                Text("Optional support. Every feature stays free, with no ads.")
                    .font(.customFont(fontFamily, style: .subheadline))
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
                Text("Support Development (Optional)")
                    .font(.customFont(fontFamily, style: .title2, weight: .semibold))

				TipJarSection(
					isPurchasing: $isPurchasing,
					showPurchaseAlert: $showPurchaseAlert,
					alertTitle: $alertTitle,
					alertMessage: $alertMessage,
					showThankYouView: $showThankYouView,
					purchaseType: $purchaseType
				)

                // Buy Me a Coffee
                BuyMeACoffeeButton()

                // Rate & Review CTA (between tips and subscriptions)
                rateAndReviewButton

				aboutButton

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
                    .font(.customFont(fontFamily, style: .body))
                    .foregroundStyle(.secondary)

                Button {
                    if let url = URL(string: "https://github.com/dan-hart/AsNeeded") {
                        openURL(url)
                    }
                } label: {
                    HStack(spacing: rowSpacing) {
                        Image(systemSymbol: .chevronLeftForwardslashChevronRight)
                            .font(.customFont(fontFamily, style: .title3))
                            .foregroundColor(.primary)

                        VStack(alignment: .leading, spacing: labelSpacing) {
                            Text("Contribute on GitHub")
                                .font(.customFont(fontFamily, style: .headline))
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)

                            Text("View source code, report issues, or contribute")
                                .font(.customFont(fontFamily, style: .subheadline))
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Image(systemSymbol: .arrowUpRight)
                            .font(.customFont(fontFamily, style: .caption))
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
                    .font(.customFont(fontFamily, style: .title3))
                    .foregroundColor(.accent)

                VStack(alignment: .leading, spacing: labelSpacing) {
                    Text("Rate & Review on App Store")
                        .font(.customFont(fontFamily, style: .headline))
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)

                    Text("Share your experience and help others discover the app")
                        .font(.customFont(fontFamily, style: .subheadline))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemSymbol: .arrowUpRight)
                    .font(.customFont(fontFamily, style: .caption))
                    .foregroundColor(.secondary)
            }
            .padding(cardPadding)
            .background(.regularMaterial)
            .cornerRadius(cardCornerRadius)
        }
        .buttonStyle(.plain)
        .padding(.top, headerPaddingV)
    }

	private var aboutButton: some View {
		NavigationLink {
			AboutView()
		} label: {
			HStack(spacing: rowSpacing) {
				Image(systemSymbol: .infoCircle)
					.font(.customFont(fontFamily, style: .title3))
					.foregroundColor(.accent)

				VStack(alignment: .leading, spacing: labelSpacing) {
					Text("About As Needed")
						.font(.customFont(fontFamily, style: .headline, weight: .semibold))
						.foregroundColor(.primary)

					Text("Version, build, and overview")
						.font(.customFont(fontFamily, style: .subheadline))
						.foregroundColor(.secondary)
				}

				Spacer()

				Image(systemSymbol: .chevronRight)
					.font(.customFont(fontFamily, style: .caption))
					.foregroundColor(.secondary)
			}
			.padding(cardPadding)
			.background(.regularMaterial)
			.cornerRadius(cardCornerRadius)
		}
		.buttonStyle(.plain)
		.padding(.top, headerPaddingV)
	}

    private var subscriptionOptions: some View {
        VStack(alignment: .leading, spacing: rowSpacing) {
            Text("Monthly Support")
                .font(.customFont(fontFamily, style: .headline))
                .fontWeight(.semibold)
                .padding(.top, headerPaddingV)

            Text("Renews automatically each month. Cancel anytime in your App Store subscription settings.")
                .font(.customFont(fontFamily, style: .caption))
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
                    alertTitle = String(localized: "Restore Complete")
                    alertMessage = String(localized: "Your purchases have been restored successfully.")
                } else {
                    alertTitle = String(localized: "Restore Failed")
                    alertMessage = revenueCatManager.purchaseError ?? String(localized: "Unable to restore purchases. Please try again later.")
                }

                showPurchaseAlert = true
            }
        } label: {
            HStack {
                Image(systemSymbol: .arrowClockwise)
                    .font(.customFont(fontFamily, style: .callout))
                Text("Restore Purchases")
                    .font(.customFont(fontFamily, style: .callout))
                    .fontWeight(.medium)
            }
            .filledButtonForeground(against: .accent)
            .padding(.horizontal, restoreButtonPaddingH)
            .padding(.vertical, buttonPaddingV)
            .background(
                RoundedRectangle(cornerRadius: buttonCornerRadius)
                    .fill(Color.accent.dynamicFilledButtonBackground)
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
                    .font(.customFont(fontFamily, style: .caption))
                    .foregroundColor(.accent)
					.frame(minHeight: 44, alignment: .leading)
            }

            Button {
                if let url = URL(string: "https://github.com/dan-hart/AsNeeded/blob/develop/PRIVACY.md") {
                    webURL = url
                    showingWebView = true
                }
            } label: {
                Text("Privacy Policy")
                    .font(.customFont(fontFamily, style: .caption))
                    .foregroundColor(.accent)
					.frame(minHeight: 44, alignment: .leading)
            }
        }
        .padding(.top, legalLinksPaddingTop)
    }

    private var subscriptionLegalInfo: some View {
        VStack(alignment: .leading, spacing: legalLinksSpacing) {
            Text("Manage or cancel in Settings > your name > Subscriptions.")
                .font(.customFont(fontFamily, style: .caption2))
                .foregroundColor(.secondary)
                .padding(.top, headerPaddingV)
        }
        .padding(.horizontal, subscriptionInfoSpacing)
    }

    private let subscriptionTiers = [
		(title: String(localized: "Supporter"), description: String(localized: "Optional monthly contribution"), icon: SFSymbol.heart, color: .accent, productId: RevenueCatManager.ProductIdentifier.subscriptionSupporter),
		(title: String(localized: "Advocate"), description: String(localized: "Optional monthly contribution"), icon: SFSymbol.handRaisedFill, color: Color.green, productId: RevenueCatManager.ProductIdentifier.subscriptionAdvocate),
		(title: String(localized: "Champion"), description: String(localized: "Optional monthly contribution"), icon: SFSymbol.crownFill, color: Color.purple, productId: RevenueCatManager.ProductIdentifier.subscriptionChampion),
    ]
}

// MARK: - Subscription Button

private struct SubscriptionButton: View {
	@Environment(\.fontFamily) private var fontFamily
	@Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric private var contentSpacing: CGFloat = 12
    @ScaledMetric private var labelSpacing: CGFloat = 2
    @ScaledMetric private var cardPadding: CGFloat = 16
    @ScaledMetric private var cardCornerRadius: CGFloat = 12
    @ScaledMetric private var borderWidth: CGFloat = 1
    @ScaledMetric private var iconSize: CGFloat = 24

	let subscription: (title: String, description: String, icon: SFSymbol, color: Color, productId: RevenueCatManager.ProductIdentifier)
    @EnvironmentObject private var revenueCatManager: RevenueCatManager
    @Binding var isPurchasing: Bool
    @Binding var showPurchaseAlert: Bool
    @Binding var alertTitle: String
    @Binding var alertMessage: String
    @Binding var showThankYouView: Bool
    @Binding var purchaseType: ThankYouView.PurchaseType?

	private var productPrice: String? {
		revenueCatManager.availableProducts.first { $0.productIdentifier == subscription.productId.rawValue }?.localizedPriceString
	}

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
                    alertTitle = String(localized: "Subscription Failed")
                    alertMessage = error
                    showPurchaseAlert = true
                }
            }
        } label: {
			let layout = dynamicTypeSize.isAccessibilitySize
				? AnyLayout(VStackLayout(alignment: .leading, spacing: contentSpacing))
				: AnyLayout(HStackLayout(spacing: contentSpacing))
			layout {
                Image(systemSymbol: subscription.icon)
                    .font(.customFont(fontFamily, style: .callout, weight: .medium))
                    .frame(width: iconSize, height: iconSize)
                    .foregroundColor(subscription.color)

                VStack(alignment: .leading, spacing: labelSpacing) {
                    Text(subscription.title)
                        .font(.customFont(fontFamily, style: .body))
                        .fontWeight(.medium)
                    Text(subscription.description)
                        .font(.customFont(fontFamily, style: .caption))
                        .foregroundColor(.secondary)
                }

				if !dynamicTypeSize.isAccessibilitySize { Spacer() }

                Text(productPrice.map { String(localized: "\($0) / month") } ?? (revenueCatManager.isLoadingProducts ? String(localized: "Loading price…") : String(localized: "Unavailable")))
                    .font(.customFont(fontFamily, style: .caption))
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
		.disabled(productPrice == nil)
    }
}

// MARK: - SafariView

struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context _: Context) -> SFSafariViewController {
        let safariViewController = SFSafariViewController(url: url)
        return safariViewController
    }

    func updateUIViewController(_: SFSafariViewController, context _: Context) {
        // No updates needed
    }
}

#if DEBUG
    #Preview {
        SupportView()
    }
#endif
