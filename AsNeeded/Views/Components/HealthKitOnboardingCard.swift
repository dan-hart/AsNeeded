// HealthKitOnboardingCard.swift
// Reusable card prompting users to connect AsNeeded with Apple Health.

import SwiftUI
import SFSafeSymbols

/// Onboarding card for HealthKit integration
/// Shows when user has no medications or in settings as a CTA
struct HealthKitOnboardingCard: View {
	@AppStorage(UserDefaultsKeys.healthKitShowOnboarding) private var showOnboarding = true
	@StateObject private var syncManager = HealthKitSyncManager.shared
	@Environment(\.fontFamily) private var fontFamily
	@State private var showAuthorizationFlow = false

	@ScaledMetric private var cardPadding: CGFloat = 20
	@ScaledMetric private var contentSpacing: CGFloat = 16
	@ScaledMetric private var iconSize: CGFloat = 48
	@ScaledMetric private var cornerRadius: CGFloat = 16
	@ScaledMetric private var buttonVerticalPadding: CGFloat = 14
	@ScaledMetric private var buttonHorizontalPadding: CGFloat = 24
	@ScaledMetric private var buttonCornerRadius: CGFloat = 12

	/// Context where the card is shown
	enum Context {
		case emptyState    // Shown in medication list when empty
		case settings      // Shown in settings as a CTA

		var title: String {
			switch self {
			case .emptyState:
				return "Sync with Apple Health"
			case .settings:
				return "Connect to Apple Health"
			}
		}

		var message: String {
			switch self {
			case .emptyState:
				return "Import your medications from Apple Health and keep everything in sync across your devices."
			case .settings:
				return "Enable HealthKit integration to sync your medication data with the Health app."
			}
		}
	}

	let context: Context

	init(context: Context = .emptyState) {
		self.context = context
	}

	var body: some View {
		if showOnboarding && !syncManager.isSyncEnabled {
			VStack(alignment: .leading, spacing: contentSpacing) {
				// MARK: - Header with Icon
				HStack(spacing: contentSpacing) {
					Image(systemSymbol: .heartTextSquareFill)
						.font(.system(size: iconSize))
						.foregroundStyle(
							LinearGradient(
								colors: [.pink, .red],
								startPoint: .topLeading,
								endPoint: .bottomTrailing
							)
						)
						.accessibilityHidden(true)

					VStack(alignment: .leading, spacing: 4) {
						Text(context.title)
							.font(.customFont(fontFamily, style: .headline, weight: .semibold))
							.foregroundColor(.primary)
							.noTruncate()

						Text("Cloud Sync")
							.font(.customFont(fontFamily, style: .caption, weight: .medium))
							.foregroundColor(.secondary)
					}
				}

				// MARK: - Description
				Text(context.message)
					.font(.customFont(fontFamily, style: .subheadline))
					.foregroundColor(.secondary)
					.fixedSize(horizontal: false, vertical: true)

				// MARK: - Benefits
				VStack(alignment: .leading, spacing: 8) {
					benefitRow(icon: .icloudFill, text: "Sync across devices")
					benefitRow(icon: .lockShieldFill, text: "Secure & private")
					benefitRow(icon: .chartLineUptrendXyaxis, text: "Comprehensive tracking")
				}

				// MARK: - Actions
				HStack(spacing: 12) {
					Button {
						showAuthorizationFlow = true
					} label: {
						Label("Connect", systemSymbol: .link)
							.font(.customFont(fontFamily, style: .body, weight: .semibold))
							.foregroundColor(.white)
							.frame(maxWidth: .infinity)
							.padding(.vertical, buttonVerticalPadding)
							.background(
								LinearGradient(
									colors: [.pink, .red],
									startPoint: .leading,
									endPoint: .trailing
								)
							)
							.cornerRadius(buttonCornerRadius)
					}
					.accessibilityLabel("Connect to Apple Health")
					.accessibilityHint("Opens flow to authorize HealthKit integration")

					Button {
						withAnimation {
							showOnboarding = false
						}
					} label: {
						Text("Not Now")
							.font(.customFont(fontFamily, style: .body, weight: .medium))
							.foregroundColor(.secondary)
							.padding(.vertical, buttonVerticalPadding)
							.padding(.horizontal, buttonHorizontalPadding)
							.background(Color(.systemGray6))
							.cornerRadius(buttonCornerRadius)
					}
					.accessibilityLabel("Dismiss HealthKit prompt")
					.accessibilityHint("Hides this card until re-enabled in preferences")
				}
			}
			.padding(cardPadding)
			.background(.regularMaterial)
			.cornerRadius(cornerRadius)
			.shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
			.sheet(isPresented: $showAuthorizationFlow) {
				HealthKitAuthorizationView()
			}
		}
	}

	// MARK: - View Components
	private func benefitRow(icon: SFSymbol, text: String) -> some View {
		HStack(spacing: 8) {
			Image(systemSymbol: icon)
				.font(.customFont(fontFamily, style: .caption, weight: .medium))
				.foregroundColor(.accent)
				.frame(width: 16)
				.accessibilityHidden(true)

			Text(text)
				.font(.customFont(fontFamily, style: .caption))
				.foregroundColor(.secondary)
		}
	}
}

#if DEBUG
#Preview("Empty State Context") {
	VStack(spacing: 20) {
		HealthKitOnboardingCard(context: .emptyState)
		Spacer()
	}
	.padding()
	.background(Color(.systemGroupedBackground))
}

#Preview("Settings Context") {
	VStack(spacing: 20) {
		HealthKitOnboardingCard(context: .settings)
		Spacer()
	}
	.padding()
	.background(Color(.systemGroupedBackground))
}
#endif
