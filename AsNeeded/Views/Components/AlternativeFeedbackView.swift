import SwiftUI
import SFSafeSymbols

struct AlternativeFeedbackView: View {
	@EnvironmentObject private var feedbackService: FeedbackService
	@Environment(\.openURL) private var openURL
	@Environment(\.dismiss) private var dismiss

	let feedbackType: FeedbackType
	@State private var showingCopiedConfirmation = false
	@State private var copiedMessage = "Copied to clipboard!"

	@ScaledMetric private var mainSpacing: CGFloat = 24
	@ScaledMetric private var headerIconSpacing: CGFloat = 16
	@ScaledMetric private var headerTextSpacing: CGFloat = 8
	@ScaledMetric private var optionsSpacing: CGFloat = 16
	@ScaledMetric private var buttonSpacing: CGFloat = 12
	@ScaledMetric private var buttonIconSpacing: CGFloat = 16
	@ScaledMetric private var buttonIconSize: CGFloat = 32
	@ScaledMetric private var buttonTextSpacing: CGFloat = 4
	@ScaledMetric private var buttonPadding: CGFloat = 16
	@ScaledMetric private var buttonCornerRadius: CGFloat = 12
	@ScaledMetric private var buttonBorderWidth: CGFloat = 0.5
	@ScaledMetric private var confirmationIconSpacing: CGFloat = 12
	@ScaledMetric private var confirmationPadding: CGFloat = 16
	@ScaledMetric private var confirmationCornerRadius: CGFloat = 12

	var body: some View {
		NavigationStack {
			VStack(spacing: mainSpacing) {
				// MARK: - Header
				headerSection

				// MARK: - Feedback Options
				VStack(spacing: optionsSpacing) {
					Text("Choose how to send feedback:", comment: "Instruction text for selecting feedback sending method")
						.font(.headline)
						.multilineTextAlignment(.center)

					feedbackOptionsSection
				}

				Spacer()
			}
			.padding()
			.navigationTitle("Send Feedback")
			.navigationBarTitleDisplayMode(.inline)
			.toolbar {
				ToolbarItem(placement: .cancellationAction) {
					Button {
						dismiss()
					} label: {
						Image(systemSymbol: .xmark)
							.font(.body.weight(.medium))
							.foregroundStyle(.secondary)
					}
				}
			}
		}
		.overlay {
			if showingCopiedConfirmation {
				copiedConfirmationOverlay
			}
		}
	}

	// MARK: - View Components

	private var headerSection: some View {
		VStack(spacing: headerIconSpacing) {
			Image(systemSymbol: .envelopeBadge)
				.font(.largeTitle)
				.foregroundStyle(.accent)

			VStack(spacing: headerTextSpacing) {
				Text("Mail App Not Configured", comment: "Title shown when Mail app is not configured for sending feedback")
					.font(.title2)
					.fontWeight(.semibold)

				Text("As Needed uses Apple's Mail app to send feedback. Choose an alternative method below or configure Mail in Settings.", comment: "Explanation message when Mail app is not configured")
					.font(.body)
					.foregroundStyle(.secondary)
					.multilineTextAlignment(.center)
			}
		}
	}

	private var feedbackOptionsSection: some View {
		VStack(spacing: buttonSpacing) {
			// Copy Support Email
			feedbackOptionButton(
				icon: .at,
				title: String(localized: "Copy Support Email", comment: "Button title to copy support email address to clipboard"),
				subtitle: String(localized: "Copy asneeded@codedbydan.com to send email manually", comment: "Button subtitle explaining what copying support email does"),
				iconColor: .accent
			) {
				copyEmailAddress()
			}

			// Open in Any Email App
			feedbackOptionButton(
				icon: .envelope,
				title: "Open Email App",
				subtitle: "Open your default email app with pre-filled content",
				iconColor: .green
			) {
				openEmailApp()
			}

			// Submit GitHub Issue
			feedbackOptionButton(
				icon: .exclamationmarkBubble,
				title: String(localized: "Submit GitHub Issue", comment: "Button title to submit feedback as GitHub issue"),
				subtitle: String(localized: "Report issues directly on GitHub for faster response", comment: "Button subtitle explaining GitHub issue benefits"),
				iconColor: .orange
			) {
				submitGitHubIssue()
			}
		}
	}

	private func feedbackOptionButton(
		icon: SFSymbol,
		title: String,
		subtitle: String,
		iconColor: Color,
		action: @escaping () -> Void
	) -> some View {
		Button(action: action) {
			HStack(spacing: buttonIconSpacing) {
				Image(systemSymbol: icon)
					.font(.title2)
					.foregroundStyle(iconColor)
					.frame(width: buttonIconSize, height: buttonIconSize)

				VStack(alignment: .leading, spacing: buttonTextSpacing) {
					Text(title)
						.font(.body)
						.fontWeight(.medium)
						.foregroundStyle(.primary)

					Text(subtitle)
						.font(.caption)
						.foregroundStyle(.secondary)
				}

				Spacer()

				Image(systemSymbol: .chevronRight)
					.font(.caption)
					.foregroundStyle(.tertiary)
			}
			.padding(buttonPadding)
			.background(Color(.systemBackground))
			.overlay(
				RoundedRectangle(cornerRadius: buttonCornerRadius)
					.stroke(Color(.systemGray4), lineWidth: buttonBorderWidth)
			)
			.cornerRadius(buttonCornerRadius)
		}
		.buttonStyle(.plain)
	}

	private var copiedConfirmationOverlay: some View {
		VStack {
			Spacer()

			HStack(spacing: confirmationIconSpacing) {
				Image(systemSymbol: .checkmarkCircleFill)
					.font(.title3)
					.foregroundStyle(.green)

				Text(copiedMessage)
					.font(.body)
					.fontWeight(.medium)
			}
			.padding(confirmationPadding)
			.background(.regularMaterial, in: RoundedRectangle(cornerRadius: confirmationCornerRadius))
			.padding(.horizontal)

			Spacer()
		}
		.transition(.opacity.combined(with: .scale))
		.onAppear {
			DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
				withAnimation {
					showingCopiedConfirmation = false
				}
			}
		}
	}

	// MARK: - Actions

	private func copyEmailAddress() {
		feedbackService.copyEmailToClipboard()
		copiedMessage = String(localized: "Support email copied!", comment: "Confirmation message when support email address is copied to clipboard")

		withAnimation {
			showingCopiedConfirmation = true
		}
	}

	private func openEmailApp() {
		if let url = feedbackService.createMailtoURL(type: feedbackType) {
			openURL(url)
			dismiss()
		}
	}

	private func submitGitHubIssue() {
		if let url = URL(string: "https://github.com/dan-hart/AsNeeded/issues/new") {
			openURL(url)
			dismiss()
		}
	}
}

#if DEBUG
#Preview {
	AlternativeFeedbackView(feedbackType: .bug)
		.environmentObject(FeedbackService.shared)
}

#Preview("Feature Request") {
	AlternativeFeedbackView(feedbackType: .featureRequest)
		.environmentObject(FeedbackService.shared)
}
#endif