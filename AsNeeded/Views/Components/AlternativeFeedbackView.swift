import SwiftUI
import SFSafeSymbols

struct AlternativeFeedbackView: View {
	@EnvironmentObject private var feedbackService: FeedbackService
	@Environment(\.openURL) private var openURL
	@Environment(\.dismiss) private var dismiss

	let feedbackType: FeedbackType
	@State private var showingCopiedConfirmation = false

	var body: some View {
		NavigationStack {
			VStack(spacing: 24) {
				// MARK: - Header
				headerSection

				// MARK: - Feedback Options
				VStack(spacing: 16) {
					Text("Choose how to send feedback:")
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
				ToolbarItem(placement: .navigationBarTrailing) {
					Button("Cancel") {
						dismiss()
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
		VStack(spacing: 16) {
			Image(systemSymbol: .envelopeBadge)
				.font(.largeTitle)
				.foregroundStyle(.accent)

			VStack(spacing: 8) {
				Text("Mail Not Available")
					.font(.title2)
					.fontWeight(.semibold)

				Text("Choose an alternative way to send your feedback")
					.font(.body)
					.foregroundStyle(.secondary)
					.multilineTextAlignment(.center)
			}
		}
	}

	private var feedbackOptionsSection: some View {
		VStack(spacing: 12) {
			// Copy to Clipboard
			feedbackOptionButton(
				icon: .documentOnClipboard,
				title: "Copy to Clipboard",
				subtitle: "Copy feedback text to paste in any app",
				iconColor: .blue
			) {
				copyToClipboard()
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

			// Share via Any App
			feedbackOptionButton(
				icon: .squareAndArrowUp,
				title: "Share via App",
				subtitle: "Share feedback through Messages, Slack, or any app",
				iconColor: .orange
			) {
				shareViaApp()
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
			HStack(spacing: 16) {
				Image(systemSymbol: icon)
					.font(.title2)
					.foregroundStyle(iconColor)
					.frame(width: 32, height: 32)

				VStack(alignment: .leading, spacing: 4) {
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
			.padding(16)
			.background(Color(.systemBackground))
			.overlay(
				RoundedRectangle(cornerRadius: 12)
					.stroke(Color(.systemGray4), lineWidth: 0.5)
			)
			.cornerRadius(12)
		}
		.buttonStyle(.plain)
	}

	private var copiedConfirmationOverlay: some View {
		VStack {
			Spacer()

			HStack(spacing: 12) {
				Image(systemSymbol: .checkmarkCircleFill)
					.font(.title3)
					.foregroundStyle(.green)

				Text("Copied to clipboard!")
					.font(.body)
					.fontWeight(.medium)
			}
			.padding(16)
			.background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
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

	private func copyToClipboard() {
		feedbackService.copyFeedbackToClipboard(type: feedbackType)

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

	private func shareViaApp() {
		let shareData = feedbackService.createShareData(type: feedbackType)

		let activityViewController = UIActivityViewController(
			activityItems: [shareData.text],
			applicationActivities: nil
		)

		activityViewController.setValue(shareData.subject, forKey: "subject")

		if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
		   let window = windowScene.windows.first {
			window.rootViewController?.present(activityViewController, animated: true)
		}

		dismiss()
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