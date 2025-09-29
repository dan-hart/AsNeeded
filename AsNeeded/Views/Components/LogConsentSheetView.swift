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
	@Environment(\.colorScheme) private var colorScheme
	@Environment(\.dismiss) private var dismiss
	@State private var isProcessing = false

	let onIncludeLogs: () -> Void
	let onSendWithoutLogs: () -> Void

	var body: some View {
		NavigationStack {
			VStack(spacing: 0) {
				ScrollView {
					VStack(spacing: 24) {
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
							.font(.body.weight(.medium))
							.foregroundStyle(.secondary)
							.padding(8)
							.background(
								Circle()
									.fill(.ultraThinMaterial)
							)
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
		VStack(spacing: 16) {
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
					.frame(width: 100, height: 100)
					.blur(radius: 20)

				// Glass circle
				Circle()
					.fill(.ultraThinMaterial)
					.frame(width: 80, height: 80)
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

				// Icon
				Image(systemSymbol: .lockShieldFill)
					.font(.largeTitle.weight(.medium))
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
				.font(.title2)
				.fontWeight(.bold)
				.foregroundStyle(.primary)
				.accessibilityAddTraits(.isHeader)

			Text("Technical logs help diagnose issues faster. Your privacy is protected—no medication names are ever stored in logs.")
				.font(.subheadline)
				.foregroundStyle(.secondary)
				.multilineTextAlignment(.center)
				.fixedSize(horizontal: false, vertical: true)
		}
		.padding(.vertical, 10)
		.accessibilityElement(children: .combine)
	}

	// MARK: - What Is Included Section
	@ViewBuilder
	private var whatIsIncludedSection: some View {
		VStack(alignment: .leading, spacing: 16) {
			HStack(spacing: 10) {
				Image(systemSymbol: .checkmarkCircleFill)
					.font(.title2)
					.foregroundStyle(.green)
					.accessibilityHidden(true)
				Text("What's Included")
					.font(.title3)
					.fontWeight(.bold)
			}
			.padding(.bottom, 4)
			.accessibilityAddTraits(.isHeader)

			VStack(alignment: .leading, spacing: 8) {
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
		VStack(alignment: .leading, spacing: 16) {
			HStack(spacing: 10) {
				Image(systemSymbol: .xmarkCircleFill)
					.font(.title2)
					.foregroundStyle(.red)
					.accessibilityHidden(true)
				Text("What's NOT Included")
					.font(.title3)
					.fontWeight(.bold)
			}
			.padding(.bottom, 4)
			.accessibilityAddTraits(.isHeader)

			VStack(alignment: .leading, spacing: 8) {
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
		VStack(spacing: 16) {
			// Include Logs button (primary action)
			Button {
				isProcessing = true
				onIncludeLogs()
				dismiss()
			} label: {
				HStack(spacing: 12) {
					Image(systemSymbol: .checkmarkCircleFill)
						.font(.title3)
						.accessibilityHidden(true)

					Text("Include Logs")
						.font(.headline)
						.fontWeight(.semibold)
				}
				.foregroundStyle(Color.green.contrastingForegroundColor(for: colorScheme))
				.frame(maxWidth: .infinity)
				.padding(.vertical, 18)
				.background(
					LinearGradient(
						colors: [Color.green, Color.green.opacity(0.8)],
						startPoint: .leading,
						endPoint: .trailing
					)
				)
				.clipShape(RoundedRectangle(cornerRadius: 16))
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
				HStack(spacing: 12) {
					if isProcessing {
						ProgressView()
							.scaleEffect(0.8)
					} else {
						Image(systemSymbol: .paperplaneFill)
							.font(.title3)
							.accessibilityHidden(true)
					}

					Text("Send Without Logs")
						.font(.headline)
						.fontWeight(.medium)
				}
				.foregroundStyle(.accent)
				.frame(maxWidth: .infinity)
				.padding(.vertical, 18)
				.background(
					RoundedRectangle(cornerRadius: 16)
						.fill(Color.accent.opacity(0.1))
						.overlay(
							RoundedRectangle(cornerRadius: 16)
								.strokeBorder(Color.accent.opacity(0.3), lineWidth: 1.5)
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
					.font(.body)
					.fontWeight(.medium)
					.foregroundStyle(.secondary)
			}
			.buttonStyle(.plain)
			.disabled(isProcessing)
			.opacity(isProcessing ? 0.6 : 1.0)
			.padding(.top, 4)
			.accessibilityLabel("Cancel")
			.accessibilityHint("Close this dialog without sending feedback")
		}
		.padding(.horizontal, 20)
		.padding(.top, 20)
		.padding(.bottom, 8)
	}

	// MARK: - Helper Views
	@ViewBuilder
	private func logItemRow(icon: SFSymbol, text: String, color: Color, isExcluded: Bool = false) -> some View {
		HStack(spacing: 12) {
			Image(systemSymbol: icon)
				.font(.body)
				.foregroundStyle(color)
				.frame(width: 20)
				.accessibilityHidden(true)

			Text(text)
				.font(.subheadline)
				.foregroundStyle(isExcluded ? .secondary : .primary)

			Spacer()

			if isExcluded {
				Image(systemSymbol: .eyeSlashFill)
					.font(.caption)
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