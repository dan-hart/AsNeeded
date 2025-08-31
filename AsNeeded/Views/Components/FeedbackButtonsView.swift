import SwiftUI
import MessageUI

struct FeedbackButtonsView: View {
    @StateObject private var feedbackService = FeedbackService.shared
    @State private var showingMailComposer = false
    
    var body: some View {
        VStack(spacing: 12) {
            Text("Help Improve AsNeeded")
                .font(.headline)
                .fontWeight(.medium)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 8) {
                FeedbackButton(
                    title: "Report a Bug",
                    icon: "exclamationmark.triangle.fill",
                    color: .red,
                    action: { feedbackService.submitFeedback(type: .bug) }
                )
                
                FeedbackButton(
                    title: "Feature Request",
                    icon: "lightbulb.fill",
                    color: .blue,
                    action: { feedbackService.submitFeedback(type: .featureRequest) }
                )
                
                FeedbackButton(
                    title: "Give Feedback",
                    icon: "heart.fill",
                    color: .green,
                    action: { feedbackService.submitFeedback(type: .feedback) }
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .overlay {
            if feedbackService.isCollectingLogs {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.3))
                    .overlay {
                        VStack(spacing: 8) {
                            ProgressView()
                                .scaleEffect(1.2)
                            Text("Collecting logs...")
                                .font(.caption)
                                .foregroundColor(.white)
                        }
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
    }
}

struct FeedbackButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .fontWeight(.medium)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(Color(.systemBackground))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
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
