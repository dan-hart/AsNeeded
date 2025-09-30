import SwiftUI
import MessageUI

struct FeedbackButtonsView: View {
    @StateObject private var feedbackService = FeedbackService.shared
    @State private var showingMailComposer = false
    @State private var currentFeedbackType: FeedbackType = .feedback
	@ScaledMetric private var containerSpacing: CGFloat = 12
	@ScaledMetric private var buttonSpacing: CGFloat = 8
	@ScaledMetric private var containerPadding: CGFloat = 20
	@ScaledMetric private var containerCornerRadius: CGFloat = 12
	@ScaledMetric private var buttonVerticalPadding: CGFloat = 12
	@ScaledMetric private var buttonHorizontalPadding: CGFloat = 16
	@ScaledMetric private var buttonCornerRadius: CGFloat = 8
	@ScaledMetric private var loadingSpacing: CGFloat = 12

    private var isLoading: Bool {
        feedbackService.isCollectingLogs || feedbackService.showingLogConsentDialog
    }

    private var loadingMessage: String {
        if feedbackService.showingLogConsentDialog {
            return "Awaiting user consent..."
        } else if feedbackService.isCollectingLogs {
            return "Preparing mail with logs..."
        } else {
            return "Loading..."
        }
    }
    
    var body: some View {
        VStack(spacing: containerSpacing) {
            Text("Help Improve AsNeeded")
                .font(.headline)
                .fontWeight(.medium)
                .frame(maxWidth: .infinity, alignment: .leading)
                .redacted(reason: isLoading ? .placeholder : [])

            VStack(spacing: buttonSpacing) {
                FeedbackButton(
                    title: "Report a Bug",
                    icon: "exclamationmark.triangle.fill",
                    color: .red,
                    isDisabled: isLoading,
                    action: {
                        currentFeedbackType = .bug
                        feedbackService.submitFeedback(type: .bug)
                    }
                )

                FeedbackButton(
                    title: "Feature Request",
                    icon: "lightbulb.fill",
                    color: .accentColor,
                    isDisabled: isLoading,
                    action: {
                        currentFeedbackType = .featureRequest
                        feedbackService.submitFeedback(type: .featureRequest)
                    }
                )

                FeedbackButton(
                    title: "Give Feedback",
                    icon: "heart.fill",
                    color: .green,
                    isDisabled: isLoading,
                    action: {
                        currentFeedbackType = .feedback
                        feedbackService.submitFeedback(type: .feedback)
                    }
                )
            }
            .redacted(reason: isLoading ? .placeholder : [])
        }
        .padding(containerPadding)
        .background(Color(.systemGray6))
        .cornerRadius(containerCornerRadius)
        .overlay {
            if isLoading {
                RoundedRectangle(cornerRadius: containerCornerRadius)
                    .fill(Color.black.opacity(0.4))
                    .overlay {
                        VStack(spacing: loadingSpacing) {
                            ProgressView()
                                .scaleEffect(1.2)
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))

                            Text(loadingMessage)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                        }
                        .padding(containerPadding)
                    }
            }
        }
        .sheet(isPresented: $feedbackService.showingMailComposer) {
            MailComposeView(feedbackService: feedbackService)
        }
        .sheet(isPresented: $feedbackService.showingFeedbackAlternatives) {
            AlternativeFeedbackView(feedbackType: currentFeedbackType)
                .environmentObject(feedbackService)
        }
        .confirmationDialog(
            "Include App Logs?",
            isPresented: $feedbackService.showingLogConsentDialog,
            titleVisibility: .visible
        ) {
            Button("Include Logs") {
                feedbackService.proceedWithLogs()
            }
            Button("Send Without Logs") {
                feedbackService.proceedWithoutLogs()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Would you like to include technical logs to help diagnose issues? No medication names are stored in logs - only technical information like app events, errors, and system information.")
        }
    }
}

struct FeedbackButton: View {
    let title: String
    let icon: String
    let color: Color
    let isDisabled: Bool
    let action: () -> Void
	@ScaledMetric private var verticalPadding: CGFloat = 12
	@ScaledMetric private var horizontalPadding: CGFloat = 16
	@ScaledMetric private var cornerRadius: CGFloat = 8

    init(title: String, icon: String, color: Color, isDisabled: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.color = color
        self.isDisabled = isDisabled
        self.action = action
    }

    var body: some View {
        Button(action: isDisabled ? {} : action) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(isDisabled ? .secondary : color)
                Text(title)
                    .fontWeight(.medium)
                    .foregroundColor(isDisabled ? .secondary : .primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.caption)
                    .opacity(isDisabled ? 0.5 : 1.0)
            }
            .padding(.vertical, verticalPadding)
            .padding(.horizontal, horizontalPadding)
            .background(Color(.systemBackground))
            .cornerRadius(cornerRadius)
            .opacity(isDisabled ? 0.6 : 1.0)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }
}

struct MailComposeView: UIViewControllerRepresentable {
    typealias UIViewControllerType = MFMailComposeViewController
    
    let feedbackService: FeedbackService
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        return feedbackService.createMailComposer()
    }
    
    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {
        // No updates needed
    }
}

#if DEBUG
#Preview {
    FeedbackButtonsView()
}
#endif
