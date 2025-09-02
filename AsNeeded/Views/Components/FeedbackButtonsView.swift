import SwiftUI
import MessageUI

struct FeedbackButtonsView: View {
    @StateObject private var feedbackService = FeedbackService.shared
    @State private var showingMailComposer = false
    
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
        VStack(spacing: 12) {
            Text("Help Improve AsNeeded")
                .font(.headline)
                .fontWeight(.medium)
                .frame(maxWidth: .infinity, alignment: .leading)
                .redacted(reason: isLoading ? .placeholder : [])
            
            VStack(spacing: 8) {
                FeedbackButton(
                    title: "Report a Bug",
                    icon: "exclamationmark.triangle.fill",
                    color: .red,
                    isDisabled: isLoading,
                    action: { feedbackService.submitFeedback(type: .bug) }
                )
                
                FeedbackButton(
                    title: "Feature Request",
                    icon: "lightbulb.fill",
                    color: .blue,
                    isDisabled: isLoading,
                    action: { feedbackService.submitFeedback(type: .featureRequest) }
                )
                
                FeedbackButton(
                    title: "Give Feedback",
                    icon: "heart.fill",
                    color: .green,
                    isDisabled: isLoading,
                    action: { feedbackService.submitFeedback(type: .feedback) }
                )
            }
            .redacted(reason: isLoading ? .placeholder : [])
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .overlay {
            if isLoading {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.4))
                    .overlay {
                        VStack(spacing: 12) {
                            ProgressView()
                                .scaleEffect(1.2)
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            
                            Text(loadingMessage)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                    }
            }
        }
        .sheet(isPresented: $feedbackService.showingMailComposer) {
            MailComposeView(feedbackService: feedbackService)
        }
        .alert("Mail Not Available", isPresented: $feedbackService.showingMailUnavailableAlert) {
            Button("OK") { }
        } message: {
            Text("Please configure Mail app or contact us directly at asneeded@codedbydan.com")
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
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(Color(.systemBackground))
            .cornerRadius(8)
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
