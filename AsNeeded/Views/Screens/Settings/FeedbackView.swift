import SwiftUI
import MessageUI
import SFSafeSymbols

struct FeedbackView: View {
	@ScaledMetric private var spacing20: CGFloat = 20
	@ScaledMetric private var spacing16: CGFloat = 16
	@ScaledMetric private var spacing12: CGFloat = 12
	@ScaledMetric private var spacing2: CGFloat = 2
	@ScaledMetric private var padding16: CGFloat = 16
	@ScaledMetric private var cornerRadius12: CGFloat = 12
	@ScaledMetric private var lineWidth05: CGFloat = 0.5
	@ScaledMetric private var iconSize24: CGFloat = 24

	@StateObject private var feedbackService = FeedbackService.shared
	@State private var showingMailComposer = false
	@State private var currentFeedbackType: FeedbackType = .feedback
	@Environment(\.colorScheme) private var colorScheme
	
	private var isLoading: Bool {
		feedbackService.isCollectingLogs || feedbackService.showingLogConsentDialog || feedbackService.isPreparingFeedback
	}
	
	private var loadingMessage: String {
		if feedbackService.showingLogConsentDialog {
			return "Awaiting user consent..."
		} else if feedbackService.isCollectingLogs {
			return "Preparing mail with logs..."
		} else if feedbackService.isPreparingFeedback {
			return "Preparing feedback..."
		} else {
			return "Loading..."
		}
	}
	
	var body: some View {
		ZStack(alignment: .top) {
			ScrollView {
				VStack(alignment: .leading, spacing: spacing20) {
					feedbackOverviewSection

					Divider()

					feedbackTypesSection

					if ReviewService.shared.canShowReviewButtons {
						Divider()

						rateAndReviewSection
					}
				}
                .padding()
			}
			.redacted(reason: isLoading ? .placeholder : [])
			.overlay {
				if isLoading {
					Color.black.opacity(0.4)
						.ignoresSafeArea()
						.overlay {
							VStack(spacing: spacing12) {
								ProgressView()
									.scaleEffect(1.2)
									.progressViewStyle(CircularProgressViewStyle(
										tint: Color(.systemGray6).contrastingForegroundColor(for: colorScheme)
									))

								Text(loadingMessage)
									.font(.subheadline)
									.fontWeight(.medium)
									.foregroundStyle(Color(.systemGray6).contrastingForegroundColor(for: colorScheme))
									.multilineTextAlignment(.center)
							}
							.padding()
							.background(Color(.systemGray6))
							.cornerRadius(cornerRadius12)
						}
				}
			}
		}
		.navigationTitle("Send Feedback")
		.navigationBarTitleDisplayMode(.large)
		.sheet(isPresented: $feedbackService.showingMailComposer) {
			MailComposeView(feedbackService: feedbackService)
		}
		.sheet(isPresented: $feedbackService.showingFeedbackAlternatives) {
			AlternativeFeedbackView(feedbackType: currentFeedbackType)
				.environmentObject(feedbackService)
		}
		.sheet(isPresented: $feedbackService.showingLogConsentDialog) {
			LogConsentSheetView(
				onIncludeLogs: {
					feedbackService.proceedWithLogs()
				},
				onSendWithoutLogs: {
					feedbackService.proceedWithoutLogs()
				}
			)
		}
	}
	
	private var feedbackOverviewSection: some View {
		VStack(alignment: .leading, spacing: spacing12) {
			Text("Help Improve As Needed")
				.font(.headline)
				.fontWeight(.semibold)

			Text("Your feedback helps make As Needed better for everyone. Choose the type of feedback you'd like to send:")
				.font(.subheadline)
				.foregroundColor(.secondary)
		}
	}
	
	private var feedbackTypesSection: some View {
		VStack(alignment: .leading, spacing: spacing16) {
			Text("Feedback Type")
				.font(.headline)
				.fontWeight(.semibold)

			VStack(spacing: spacing12) {
				feedbackTypeButton(
					title: "Report a Bug",
					subtitle: "Something isn't working correctly",
					systemImage: .exclamationmarkTriangle,
					color: .red,
					action: {
						currentFeedbackType = .bug
						feedbackService.submitFeedback(type: .bug)
					}
				)

				feedbackTypeButton(
					title: "Request a Feature",
					subtitle: "Suggest new functionality or improvements",
					systemImage: .lightbulb,
					color: .orange,
					action: {
						currentFeedbackType = .featureRequest
						feedbackService.submitFeedback(type: .featureRequest)
					}
				)

				feedbackTypeButton(
					title: "General Feedback",
					subtitle: "Share your thoughts and experiences",
					systemImage: .heart,
					color: .green,
					action: {
						currentFeedbackType = .feedback
						feedbackService.submitFeedback(type: .feedback)
					}
				)
			}
		}
	}

	private var rateAndReviewSection: some View {
		VStack(alignment: .leading, spacing: spacing16) {
			Text("Love As Needed?")
				.font(.headline)
				.fontWeight(.semibold)

			feedbackTypeButton(
				title: "Rate & Review on App Store",
				subtitle: "Share your experience and help others discover the app",
				systemImage: .star,
				color: .accent,
				action: {
					Task {
						await AppReviewManager.shared.requestReviewWithAlert()
					}
				}
			)
		}
	}

	private func feedbackTypeButton(
		title: String,
		subtitle: String,
		systemImage: SFSymbol,
		color: Color,
		action: @escaping () -> Void
	) -> some View {
		Button(action: isLoading ? {} : action) {
			HStack(spacing: spacing12) {
				Image(systemSymbol: systemImage)
					.font(.system(.callout, design: .default, weight: .medium))
					.frame(width: iconSize24, height: iconSize24)
					.foregroundColor(isLoading ? .secondary : color)

				VStack(alignment: .leading, spacing: spacing2) {
					Text(title)
						.font(.body)
						.fontWeight(.medium)
						.foregroundColor(isLoading ? .secondary : .primary)

					Text(subtitle)
						.font(.caption)
						.foregroundColor(.secondary)
				}

				Spacer()

				Image(systemSymbol: .chevronRight)
					.font(.caption)
					.foregroundColor(.secondary)
					.opacity(isLoading ? 0.5 : 1.0)
			}
			.padding(padding16)
			.background(Color(.systemBackground))
			.overlay(
				RoundedRectangle(cornerRadius: cornerRadius12)
					.stroke(Color(.systemGray4), lineWidth: lineWidth05)
			)
			.cornerRadius(cornerRadius12)
			.opacity(isLoading ? 0.6 : 1.0)
		}
		.buttonStyle(.plain)
		.disabled(isLoading)
	}
}


#if DEBUG
#Preview {
	NavigationView {
		FeedbackView()
			.padding()
	}
}
#endif
