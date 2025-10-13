import SwiftUI
import SFSafeSymbols

/// A prominent sheet view for obtaining user consent to include logs in feedback
///
/// Features:
/// - Eye-catching hero section with privacy-focused icon
/// - Clear explanation of what data is and isn't included
/// - Visual breakdown of log contents using glass cards
/// - Large, accessible action buttons with clear hierarchy
/// - Privacy-first messaging emphasizing no medication names in logs
///
/// **Appearance:**
/// - Hero section with shield/lock icon in gradient circle
/// - Glass card sections explaining log contents
/// - Green "Include Logs" button (helpful action)
/// - Secondary "Send Without Logs" button (alternative action)
/// - Red "Cancel" link (destructive/dismissive action)
/// - Generous spacing and padding for readability
///
/// **Use Cases:**
/// - Feedback submission flows requiring log attachment consent
/// - Bug report screens where logs help diagnose issues
/// - Any feature requesting technical diagnostic data
/// - Privacy-sensitive data collection prompts
/// - Support ticket creation with optional diagnostics
struct LogConsentSheetView: View {
	@Environment(\.fontFamily) private var fontFamily
	@Environment(\.colorScheme) private var colorScheme
	@Environment(\.dismiss) private var dismiss
	@State private var isProcessing = false

	let onIncludeLogs: () -> Void
	let onSendWithoutLogs: () -> Void

	@ScaledMetric private var mainSpacing: CGFloat = 24
	@ScaledMetric private var heroSpacing: CGFloat = 16
	@ScaledMetric private var heroIconSize: CGFloat = 100
	@ScaledMetric private var heroGlassSize: CGFloat = 80
	@ScaledMetric private var heroVPadding: CGFloat = 10
	@ScaledMetric private var sectionSpacing: CGFloat = 16
	@ScaledMetric private var sectionHSpacing: CGFloat = 10
	@ScaledMetric private var sectionBottomPadding: CGFloat = 4
	@ScaledMetric private var itemRowSpacing: CGFloat = 8
	@ScaledMetric private var itemIconWidth: CGFloat = 20
	@ScaledMetric private var headerSpacing: CGFloat = 12
	@ScaledMetric private var actionButtonSpacing: CGFloat = 16
	@ScaledMetric private var actionButtonIconSpacing: CGFloat = 12
	@ScaledMetric private var actionButtonVPadding: CGFloat = 18
	@ScaledMetric private var actionButtonCornerRadius: CGFloat = 16
	@ScaledMetric private var actionButtonBorderWidth: CGFloat = 1.5
	@ScaledMetric private var actionTopPadding: CGFloat = 20
	@ScaledMetric private var actionBottomPadding: CGFloat = 8
	@ScaledMetric private var actionHPadding: CGFloat = 20
	@ScaledMetric private var cancelTopPadding: CGFloat = 4
	@ScaledMetric private var toolbarPadding: CGFloat = 8

	var body: some View {
		NavigationStack {
			VStack(spacing: 0) {
				ScrollView {
					VStack(spacing: mainSpacing) {
						heroSection
						whatIsIncludedSection
						whatIsNotIncludedSection

						// Bottom padding for scroll content
						Color.clear.frame(height: 20)
					}
					.padding()
				}
				.background(
					LinearGradient(
						colors: [
							Color(.systemGroupedBackground),
							Color.green.opacity(0.05)
						],
						startPoint: .top,
						endPoint: .bottom
					)
					.ignoresSafeArea()
				)

				// Sticky action buttons at bottom
				actionButtonsSection
					.background(
						VStack(spacing: 0) {
							// Top shadow for elevation effect
							LinearGradient(
								colors: [
									Color.black.opacity(0.1),
									Color.clear
								],
								startPoint: .top,
								endPoint: .bottom
							)
							.frame(height: 8)

							// Background
							Color(.systemBackground)
						}
						.ignoresSafeArea(edges: .bottom)
					)
			}
			.navigationTitle("Include App Logs?")
			.navigationBarTitleDisplayMode(.inline)
			.toolbar {
				ToolbarItem(placement: .cancellationAction) {
					Button {
						dismiss()
					} label: {
						Image(systemSymbol: .xmark)
							.font(.customFont(fontFamily, style: .body, weight: .medium))
							.foregroundStyle(.secondary)
					}
				}
			}
		}
		.presentationDetents([.large])
		.presentationDragIndicator(.visible)
	}

	// MARK: - Hero Section
	@ViewBuilder
	private var heroSection: some View {
		VStack(spacing: heroSpacing) {
			// Animated icon with glass effect
			ZStack {
				// Animated gradient background
				Circle()
					.fill(
						LinearGradient(
							colors: [
								Color.green.opacity(0.3),
								Color.green.opacity(0.1)
							],
							startPoint: .topLeading,
							endPoint: .bottomTrailing
						)
					)
					.frame(width: heroIconSize, height: heroIconSize)
					.blur(radius: 20)

				// Glass circle
				Circle()
					.fill(.regularMaterial)
					.frame(width: heroGlassSize, height: heroGlassSize)
					.overlay(
						Circle()
							.strokeBorder(
								LinearGradient(
									colors: [
										.white.opacity(0.6),
										.white.opacity(0.2)
									],
									startPoint: .topLeading,
									endPoint: .bottomTrailing
								),
								lineWidth: 1
							)
					)
					.overlay(
						// Specular highlight for premium glass effect
						Circle()
							.fill(
								LinearGradient(
									colors: [
										.white.opacity(0.3),
										.clear,
										.white.opacity(0.1)
									],
									startPoint: .topLeading,
									endPoint: .bottomTrailing
								)
							)
							.blendMode(.overlay)
					)

				// Icon
				Image(systemSymbol: .lockShieldFill)
					.font(.customFont(fontFamily, style: .largeTitle, weight: .medium))
					.foregroundStyle(
						LinearGradient(
							colors: [Color.green, Color.green.opacity(0.7)],
							startPoint: .top,
							endPoint: .bottom
						)
					)
					.accessibilityHidden(true)
			}

			Text("Help Us Improve")
				.font(.customFont(fontFamily, style: .title2, weight: .bold))
				.foregroundStyle(.primary)
				.accessibilityAddTraits(.isHeader)

			Text("Technical logs help diagnose issues faster. Your privacy is protected—no medication names are ever stored in logs.")
				.font(.customFont(fontFamily, style: .subheadline))
				.foregroundStyle(.secondary)
				.multilineTextAlignment(.center)
				.fixedSize(horizontal: false, vertical: true)
		}
		.padding(.vertical, heroVPadding)
		.accessibilityElement(children: .combine)
	}

	// MARK: - What Is Included Section
	@ViewBuilder
	private var whatIsIncludedSection: some View {
		VStack(alignment: .leading, spacing: sectionSpacing) {
			HStack(spacing: sectionHSpacing) {
				Image(systemSymbol: .checkmarkCircleFill)
					.font(.customFont(fontFamily, style: .title2))
					.foregroundStyle(.green)
					.accessibilityHidden(true)
				Text("What's Included")
					.font(.customFont(fontFamily, style: .title3, weight: .bold))
			}
			.padding(.bottom, sectionBottomPadding)
			.accessibilityAddTraits(.isHeader)

			VStack(alignment: .leading, spacing: itemRowSpacing) {
				logItemRow(icon: .gearshapeFill, text: "App events and actions", color: .blue)
				logItemRow(icon: .exclamationmarkTriangleFill, text: "Error messages and warnings", color: .orange)
				logItemRow(icon: .infoCircleFill, text: "System information (iOS version, device model)", color: .cyan)
				logItemRow(icon: .clockFill, text: "Timestamps of app activities", color: .purple)
			}
		}
		.glassCard()
		.padding(.horizontal)
		.accessibilityElement(children: .combine)
	}

	// MARK: - What Is Not Included Section
	@ViewBuilder
	private var whatIsNotIncludedSection: some View {
		VStack(alignment: .leading, spacing: sectionSpacing) {
			HStack(spacing: sectionHSpacing) {
				Image(systemSymbol: .xmarkCircleFill)
					.font(.customFont(fontFamily, style: .title2))
					.foregroundStyle(.red)
					.accessibilityHidden(true)
				Text("What's NOT Included")
					.font(.customFont(fontFamily, style: .title3, weight: .bold))
			}
			.padding(.bottom, sectionBottomPadding)
			.accessibilityAddTraits(.isHeader)

			VStack(alignment: .leading, spacing: itemRowSpacing) {
				logItemRow(icon: .pillsFill, text: "Medication names", color: .red, isExcluded: true)
				logItemRow(icon: .personFill, text: "Personal health information", color: .red, isExcluded: true)
				logItemRow(icon: .lockFill, text: "Any sensitive user data", color: .red, isExcluded: true)
			}
		}
		.glassCard()
		.padding(.horizontal)
		.accessibilityElement(children: .combine)
	}

	// MARK: - Action Buttons Section
	@ViewBuilder
	private var actionButtonsSection: some View {
		VStack(spacing: actionButtonSpacing) {
			// Include Logs button (primary action)
			Button {
				isProcessing = true
				onIncludeLogs()
				dismiss()
			} label: {
				HStack(spacing: actionButtonIconSpacing) {
					Image(systemSymbol: .checkmarkCircleFill)
						.font(.customFont(fontFamily, style: .title3))
						.accessibilityHidden(true)

					Text("Include Logs")
						.font(.customFont(fontFamily, style: .headline, weight: .semibold))
				}
				.foregroundStyle(Color.green.contrastingForegroundColor(for: colorScheme))
				.frame(maxWidth: .infinity)
				.padding(.vertical, actionButtonVPadding)
				.background(
					LinearGradient(
						colors: [Color.green, Color.green.opacity(0.8)],
						startPoint: .leading,
						endPoint: .trailing
					)
				)
				.clipShape(RoundedRectangle(cornerRadius: actionButtonCornerRadius))
				.shadow(color: Color.green.opacity(0.3), radius: 10, y: 5)
			}
			.buttonStyle(.plain)
			.disabled(isProcessing)
			.opacity(isProcessing ? 0.6 : 1.0)
			.accessibilityLabel("Include Logs")
			.accessibilityHint("Attach technical logs to your feedback to help diagnose issues")

			// Send Without Logs button (secondary action)
			Button {
				isProcessing = true
				onSendWithoutLogs()
				dismiss()
			} label: {
				HStack(spacing: actionButtonIconSpacing) {
					if isProcessing {
						ProgressView()
							.scaleEffect(0.8)
					} else {
						Image(systemSymbol: .paperplaneFill)
							.font(.customFont(fontFamily, style: .title3))
							.accessibilityHidden(true)
					}

					Text("Send Without Logs")
						.font(.customFont(fontFamily, style: .headline, weight: .medium))
				}
				.foregroundStyle(.accent)
				.frame(maxWidth: .infinity)
				.padding(.vertical, actionButtonVPadding)
				.background(
					RoundedRectangle(cornerRadius: actionButtonCornerRadius)
						.fill(Color.accent.opacity(0.1))
						.overlay(
							RoundedRectangle(cornerRadius: actionButtonCornerRadius)
								.strokeBorder(Color.accent.opacity(0.3), lineWidth: actionButtonBorderWidth)
						)
				)
			}
			.buttonStyle(.plain)
			.disabled(isProcessing)
			.opacity(isProcessing ? 0.6 : 1.0)
			.accessibilityLabel("Send Without Logs")
			.accessibilityHint("Send feedback without attaching technical logs")

			// Cancel button (tertiary action)
			Button(role: .cancel) {
				dismiss()
			} label: {
				Text("Cancel")
					.font(.customFont(fontFamily, style: .body, weight: .medium))
					.foregroundStyle(.secondary)
			}
			.buttonStyle(.plain)
			.disabled(isProcessing)
			.opacity(isProcessing ? 0.6 : 1.0)
			.padding(.top, cancelTopPadding)
			.accessibilityLabel("Cancel")
			.accessibilityHint("Close this dialog without sending feedback")
		}
		.padding(.horizontal, actionHPadding)
		.padding(.top, actionTopPadding)
		.padding(.bottom, actionBottomPadding)
	}

	// MARK: - Helper Views
	@ViewBuilder
	private func logItemRow(icon: SFSymbol, text: String, color: Color, isExcluded: Bool = false) -> some View {
		HStack(spacing: headerSpacing) {
			Image(systemSymbol: icon)
				.font(.customFont(fontFamily, style: .body))
				.foregroundStyle(color)
				.frame(width: itemIconWidth)
				.accessibilityHidden(true)

			Text(text)
				.font(.customFont(fontFamily, style: .subheadline))
				.foregroundStyle(isExcluded ? .secondary : .primary)

			Spacer()

			if isExcluded {
				Image(systemSymbol: .eyeSlashFill)
					.font(.customFont(fontFamily, style: .caption))
					.foregroundStyle(.secondary)
					.accessibilityHidden(true)
			}
		}
		.accessibilityElement(children: .combine)
	}
}

#if DEBUG
#Preview {
	LogConsentSheetView(
		onIncludeLogs: {
			print("Include logs tapped")
		},
		onSendWithoutLogs: {
			print("Send without logs tapped")
		}
	)
}
#endif