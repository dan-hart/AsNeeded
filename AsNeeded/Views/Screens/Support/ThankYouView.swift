import SwiftUI
import SFSafeSymbols
import DHLoggingKit

struct ThankYouView: View {
	@ScaledMetric private var sectionSpacing: CGFloat = 32
	@ScaledMetric private var heroSpacing: CGFloat = 20
	@ScaledMetric private var contentSpacing: CGFloat = 16
	@ScaledMetric private var itemSpacing: CGFloat = 12
	@ScaledMetric private var compactSpacing: CGFloat = 8
	@ScaledMetric private var labelSpacing: CGFloat = 2
	@ScaledMetric private var buttonPaddingV: CGFloat = 16
	@ScaledMetric private var dismissButtonPaddingTop: CGFloat = 8
	@ScaledMetric private var impactCardCornerRadius: CGFloat = 16
	@ScaledMetric private var buttonCornerRadius: CGFloat = 14
	@ScaledMetric private var actionCardCornerRadius: CGFloat = 12
	@ScaledMetric private var iconCornerRadius: CGFloat = 10
	@ScaledMetric private var heroCircleSize: CGFloat = 120
	@ScaledMetric private var actionIconSize: CGFloat = 40
	@ScaledMetric private var impactIconWidth: CGFloat = 24
	@ScaledMetric private var heroBlurRadius: CGFloat = 20
	@ScaledMetric private var buttonShadowRadius: CGFloat = 8
	@ScaledMetric private var buttonShadowY: CGFloat = 4

	@Environment(\.dismiss) private var dismiss
	@Environment(\.openURL) private var openURL
	@Environment(\.accessibilityReduceMotion) private var reduceMotion
	@Environment(\.fontFamily) private var fontFamily
	@EnvironmentObject private var feedbackService: FeedbackService

	let purchaseType: PurchaseType
	@State private var showConfetti = false
	@State private var heartScale: CGFloat = 0.5
	@State private var messageOpacity: Double = 0
	@State private var buttonsOpacity: Double = 0
	
	enum PurchaseType {
		case tip(amount: String)
		case subscription(plan: String)
		
		var title: String {
			switch self {
			case .tip:
				return "Thank You for Your Tip!"
			case .subscription:
				return "Thank You for Your Continued Support!"
			}
		}
		
		var subtitle: String {
			switch self {
			case .tip(let amount):
				return "Your \(amount) tip means the world"
			case .subscription(let plan):
				return "You're now subscribed to \(plan)"
			}
		}
	}
	
	var body: some View {
		NavigationStack {
			ScrollView {
				VStack(spacing: sectionSpacing) {
					// MARK: - Hero Section
					heroSection

					// MARK: - Impact Message
					impactSection
						.opacity(messageOpacity)
						.animation(reduceMotion ? .none : .easeInOut(duration: 0.8).delay(0.5), value: messageOpacity)

					// MARK: - Ways to Contribute
					contributeSection
						.opacity(buttonsOpacity)
						.animation(reduceMotion ? .none : .easeInOut(duration: 0.8).delay(1.0), value: buttonsOpacity)

					// MARK: - Personal Note
					personalNoteSection
						.opacity(buttonsOpacity)
						.animation(.easeInOut(duration: 0.8).delay(1.2), value: buttonsOpacity)

					// MARK: - Dismiss Button
					dismissButton
						.opacity(buttonsOpacity)
						.animation(.easeInOut(duration: 0.8).delay(1.4), value: buttonsOpacity)
				}
				.padding()
			}
			.navigationBarTitleDisplayMode(.inline)
			.toolbar {
				ToolbarItem(placement: .confirmationAction) {
					Button(action: { dismiss() }) {
						Image(systemSymbol: .checkmarkCircleFill)
							.font(.customFont(fontFamily, style: .title2, weight: .semibold))
							.foregroundStyle(.accent)
					}
				}
			}
		}
		.onAppear {
			if reduceMotion {
				// Immediately show content without animations
				heartScale = 1.0
				showConfetti = false
				messageOpacity = 1.0
				buttonsOpacity = 1.0
			} else {
				withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
					heartScale = 1.0
				}
				withAnimation {
					showConfetti = true
					messageOpacity = 1.0
					buttonsOpacity = 1.0
				}
			}
			DHLogger.ui.info("ThankYouView appeared for \(String(describing: purchaseType))")
		}
	}
	
	// MARK: - View Components
	private var heroSection: some View {
		VStack(spacing: heroSpacing) {
			// Animated Heart Icon
			ZStack {
				Circle()
					.fill(
						LinearGradient(
							colors: [Color.pink.opacity(0.3), Color.red.opacity(0.3)],
							startPoint: .topLeading,
							endPoint: .bottomTrailing
						)
					)
					.frame(width: heroCircleSize, height: heroCircleSize)
					.blur(radius: heroBlurRadius)

				Image(systemSymbol: .heartFill)
					.font(.largeTitle.weight(.semibold))
					.foregroundStyle(
						LinearGradient(
							colors: [.pink, .red],
							startPoint: .topLeading,
							endPoint: .bottomTrailing
						)
					)
					.scaleEffect(heartScale)
					.animation(
						.spring(response: 0.5, dampingFraction: 0.6)
							.repeatCount(3, autoreverses: true),
						value: heartScale
					)
			}
			.padding(.top, heroSpacing)

			VStack(spacing: compactSpacing) {
				Text(purchaseType.title)
					.font(.largeTitle)
					.fontWeight(.bold)
					.multilineTextAlignment(.center)

				Text(purchaseType.subtitle)
					.font(.title3)
					.foregroundColor(.secondary)
					.multilineTextAlignment(.center)
			}
		}
	}
	
	private var impactSection: some View {
		VStack(alignment: .leading, spacing: contentSpacing) {
			Label {
				Text("Your Support Helps")
					.font(.customFont(fontFamily, style: .headline))
			} icon: {
				Image(systemSymbol: .sparkles)
			}
			.foregroundColor(.accentColor)

			VStack(alignment: .leading, spacing: itemSpacing) {
				ImpactRow(
					icon: .hammerFill,
					title: "Continuous Development",
					description: "Regular updates with new features and improvements"
				)

				ImpactRow(
					icon: .shieldLefthalfFilled,
					title: "Privacy-First Approach",
					description: "Keeping the app ad-free and your data private"
				)

				ImpactRow(
					icon: .heartTextSquareFill,
					title: "Community Support",
					description: "Responding to feedback and helping users"
				)

				ImpactRow(
					icon: .globeAmericasFill,
					title: "Open Source Mission",
					description: "Maintaining free access to core features for everyone"
				)
			}
			.padding()
			.background(
				RoundedRectangle(cornerRadius: impactCardCornerRadius)
					.fill(.quaternary.opacity(0.3))
			)
		}
	}
	
	private var contributeSection: some View {
		VStack(alignment: .leading, spacing: contentSpacing) {
			Label {
				Text("Want to Contribute More?")
					.font(.customFont(fontFamily, style: .headline))
			} icon: {
				Image(systemSymbol: .personCropCircleBadgePlus)
			}
			.foregroundColor(.accentColor)

			VStack(spacing: itemSpacing) {
				// GitHub Repository
				Button(action: openGitHub) {
					HStack {
						Image(systemSymbol: .chevronLeftForwardslashChevronRight)
							.font(.title2)
							.foregroundColor(.white)
							.frame(width: actionIconSize, height: actionIconSize)
							.background(
								LinearGradient(
									colors: [.purple, .indigo],
									startPoint: .topLeading,
									endPoint: .bottomTrailing
								)
							)
							.cornerRadius(iconCornerRadius)

						VStack(alignment: .leading, spacing: labelSpacing) {
							Text("View Source Code")
								.font(.callout)
								.fontWeight(.semibold)
								.foregroundColor(.primary)
							Text("Contribute on GitHub")
								.font(.caption)
								.foregroundColor(.secondary)
						}

						Spacer()

						Image(systemSymbol: .arrowUpRight)
							.font(.caption)
							.foregroundColor(.secondary)
					}
					.padding()
					.background(
						RoundedRectangle(cornerRadius: actionCardCornerRadius)
							.fill(.quaternary.opacity(0.2))
					)
				}
				.buttonStyle(.plain)
				
				// Submit Issue
				Button(action: openGitHubIssues) {
					HStack {
						Image(systemSymbol: .exclamationmarkTriangleFill)
							.font(.title2)
							.foregroundColor(.white)
							.frame(width: actionIconSize, height: actionIconSize)
							.background(
								LinearGradient(
									colors: [.orange, .yellow],
									startPoint: .topLeading,
									endPoint: .bottomTrailing
								)
							)
							.cornerRadius(iconCornerRadius)

						VStack(alignment: .leading, spacing: labelSpacing) {
							Text("Report an Issue")
								.font(.callout)
								.fontWeight(.semibold)
								.foregroundColor(.primary)
							Text("Help improve the app")
								.font(.caption)
								.foregroundColor(.secondary)
						}

						Spacer()

						Image(systemSymbol: .arrowUpRight)
							.font(.caption)
							.foregroundColor(.secondary)
					}
					.padding()
					.background(
						RoundedRectangle(cornerRadius: actionCardCornerRadius)
							.fill(.quaternary.opacity(0.2))
					)
				}
				.buttonStyle(.plain)

				// Send Feedback
				Button(action: sendFeedback) {
					HStack {
						Image(systemSymbol: .envelopeFill)
							.font(.title2)
							.foregroundColor(.white)
							.frame(width: actionIconSize, height: actionIconSize)
							.background(
								LinearGradient(
									colors: [.blue, .cyan],
									startPoint: .topLeading,
									endPoint: .bottomTrailing
								)
							)
							.cornerRadius(iconCornerRadius)

						VStack(alignment: .leading, spacing: labelSpacing) {
							Text("Send Feedback")
								.font(.callout)
								.fontWeight(.semibold)
								.foregroundColor(.primary)
							Text("asneeded@codedbydan.com")
								.font(.caption)
								.foregroundColor(.secondary)
						}

						Spacer()

						Image(systemSymbol: .paperplaneFill)
							.font(.caption)
							.foregroundColor(.secondary)
					}
					.padding()
					.background(
						RoundedRectangle(cornerRadius: actionCardCornerRadius)
							.fill(.quaternary.opacity(0.2))
					)
				}
				.buttonStyle(.plain)

				// Rate & Review
				Button(action: openAppStoreReview) {
					HStack {
						Image(systemSymbol: .star)
							.font(.title2)
							.foregroundColor(.white)
							.frame(width: actionIconSize, height: actionIconSize)
							.background(
								LinearGradient(
									colors: [.orange, .yellow],
									startPoint: .topLeading,
									endPoint: .bottomTrailing
								)
							)
							.cornerRadius(iconCornerRadius)

						VStack(alignment: .leading, spacing: labelSpacing) {
							Text("Rate & Review")
								.font(.callout)
								.fontWeight(.semibold)
								.foregroundColor(.primary)
							Text("Share your experience on the App Store")
								.font(.caption)
								.foregroundColor(.secondary)
						}

						Spacer()

						Image(systemSymbol: .arrowUpRight)
							.font(.caption)
							.foregroundColor(.secondary)
					}
					.padding()
					.background(
						RoundedRectangle(cornerRadius: actionCardCornerRadius)
							.fill(.quaternary.opacity(0.2))
					)
				}
				.buttonStyle(.plain)

				// TestFlight Beta
				TestFlightAccessComponent()
			}
		}
	}
	
	private var personalNoteSection: some View {
		VStack(alignment: .leading, spacing: itemSpacing) {
			HStack {
				Image(systemSymbol: .personCircleFill)
					.foregroundColor(.accentColor)
				Text("A Note from the Developer")
					.font(.customFont(fontFamily, style: .headline))
			}

			Text("Your support truly makes a difference. As an independent developer, contributions like yours allow me to dedicate time to making AsNeeded better for everyone. Thank you for believing in this project and being part of our community. 💙")
				.font(.callout)
				.foregroundColor(.secondary)
				.fixedSize(horizontal: false, vertical: true)
				.padding()
				.background(
					RoundedRectangle(cornerRadius: actionCardCornerRadius)
						.fill(Color.accentColor.opacity(0.1))
				)
		}
	}
	
	private var dismissButton: some View {
		Button(action: { dismiss() }) {
			HStack {
				Spacer()
				Text("Continue")
					.font(.headline)
					.foregroundColor(.white)
				Image(systemSymbol: .arrowRight)
					.font(.headline)
					.foregroundColor(.white)
				Spacer()
			}
			.padding(.vertical, buttonPaddingV)
			.background(
				LinearGradient(
					colors: [.accentColor, .accentColor.opacity(0.8)],
					startPoint: .leading,
					endPoint: .trailing
				)
			)
			.cornerRadius(buttonCornerRadius)
			.shadow(color: .accentColor.opacity(0.3), radius: buttonShadowRadius, y: buttonShadowY)
		}
		.buttonStyle(.plain)
		.padding(.top, dismissButtonPaddingTop)
	}
	
	// MARK: - Actions
	private func openGitHub() {
		if let url = URL(string: "https://github.com/dan-hart/AsNeeded") {
			openURL(url)
			DHLogger.ui.info("Opened GitHub repository")
		}
	}
	
	private func openGitHubIssues() {
		if let url = URL(string: "https://github.com/dan-hart/AsNeeded/issues/new") {
			openURL(url)
			DHLogger.ui.info("Opened GitHub issues")
		}
	}
	
	private func sendFeedback() {
		feedbackService.submitFeedback(type: .feedback)
		DHLogger.ui.info("Initiated feedback email")
	}

	private func openAppStoreReview() {
		ReviewService.shared.openAppStoreReviewPage()
		DHLogger.ui.info("Opened App Store review page")
	}
}

// MARK: - Supporting Views
private struct ImpactRow: View {
	@ScaledMetric private var rowSpacing: CGFloat = 12
	@ScaledMetric private var labelSpacing: CGFloat = 4
	@ScaledMetric private var iconWidth: CGFloat = 24

	let icon: SFSymbol
	let title: String
	let description: String

	var body: some View {
		HStack(alignment: .top, spacing: rowSpacing) {
			Image(systemSymbol: icon)
				.font(.body)
				.foregroundColor(.accentColor)
				.frame(width: iconWidth)

			VStack(alignment: .leading, spacing: labelSpacing) {
				Text(title)
					.font(.subheadline)
					.fontWeight(.semibold)
				Text(description)
					.font(.caption)
					.foregroundColor(.secondary)
					.fixedSize(horizontal: false, vertical: true)
			}
		}
	}
}

// MARK: - Confetti Modifier
struct ConfettiModifier: ViewModifier {
	@State private var confettiPieces: [ConfettiPiece] = []
	let isActive: Bool
	
	func body(content: Content) -> some View {
		content
			.overlay(
				GeometryReader { geometry in
					ZStack {
						ForEach(confettiPieces) { piece in
							Image(systemSymbol: piece.symbol)
								.foregroundColor(piece.color)
								.font(.callout)
								.position(piece.position)
								.opacity(piece.opacity)
								.rotationEffect(.degrees(piece.rotation))
						}
					}
					.onAppear {
						if isActive {
							createConfetti(in: geometry.size)
						}
					}
				}
			)
	}
	
	private func createConfetti(in size: CGSize) {
		confettiPieces = (0..<30).map { _ in
			ConfettiPiece(
				symbol: [.heartFill, .starFill, .sparkle, .circlebadgeFill].randomElement() ?? .starFill,
				color: [.pink, .purple, .blue, .orange, .yellow].randomElement() ?? .pink,
				size: CGFloat.random(in: 12...24),
				position: CGPoint(
					x: CGFloat.random(in: 0...size.width),
					y: -50
				),
				opacity: 1.0,
				rotation: Double.random(in: 0...360)
			)
		}
		
		// Animate confetti falling
		withAnimation(.easeOut(duration: 3)) {
			confettiPieces = confettiPieces.map { piece in
				var newPiece = piece
				newPiece.position.y = size.height + 100
				newPiece.opacity = 0
				newPiece.rotation = piece.rotation + Double.random(in: 180...540)
				return newPiece
			}
		}
	}
}

private struct ConfettiPiece: Identifiable {
	let id = UUID()
	let symbol: SFSymbol
	let color: Color
	let size: CGFloat
	var position: CGPoint
	var opacity: Double
	var rotation: Double
}

// MARK: - Preview
#Preview("Tip Purchase") {
	ThankYouView(purchaseType: .tip(amount: "$4.99"))
		.environmentObject(FeedbackService.shared)
}

#Preview("Subscription") {
	ThankYouView(purchaseType: .subscription(plan: "Monthly Pro"))
		.environmentObject(FeedbackService.shared)
}
