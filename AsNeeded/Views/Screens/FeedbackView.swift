import SwiftUI
import MessageUI
import SFSafeSymbols

struct FeedbackView: View {
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
		ZStack(alignment: .top) {
			ScrollView {
				VStack(alignment: .leading, spacing: 20) {
					feedbackOverviewSection
					
					Divider()
					
					feedbackTypesSection
				}
                .padding()
			}
			.redacted(reason: isLoading ? .placeholder : [])
			.overlay {
				if isLoading {
					Color.black.opacity(0.4)
						.ignoresSafeArea()
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
							.background(Color(.systemGray6))
							.cornerRadius(12)
						}
				}
			}
		}
		.navigationTitle("Send Feedback")
		.navigationBarTitleDisplayMode(.large)
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
	
	private var feedbackOverviewSection: some View {
		VStack(alignment: .leading, spacing: 12) {
			Text("Help Improve As Needed")
				.font(.headline)
				.fontWeight(.semibold)
			
			Text("Your feedback helps make As Needed better for everyone. Choose the type of feedback you'd like to send:")
				.font(.subheadline)
				.foregroundColor(.secondary)
		}
	}
	
	private var feedbackTypesSection: some View {
		VStack(alignment: .leading, spacing: 16) {
			Text("Feedback Type")
				.font(.headline)
				.fontWeight(.semibold)
			
			VStack(spacing: 12) {
				feedbackTypeButton(
					title: "Report a Bug",
					subtitle: "Something isn't working correctly",
					systemImage: .exclamationmarkTriangle,
					color: .red,
					action: { feedbackService.submitFeedback(type: .bug) }
				)
				
				feedbackTypeButton(
					title: "Request a Feature",
					subtitle: "Suggest new functionality or improvements",
					systemImage: .lightbulb,
					color: .orange,
					action: { feedbackService.submitFeedback(type: .featureRequest) }
				)
				
				feedbackTypeButton(
					title: "General Feedback",
					subtitle: "Share your thoughts and experiences",
					systemImage: .heart,
					color: .green,
					action: { feedbackService.submitFeedback(type: .feedback) }
				)
			}
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
			HStack(spacing: 12) {
				Image(systemSymbol: systemImage)
					.font(.system(size: 18, weight: .medium))
					.frame(width: 24, height: 24)
					.foregroundColor(isLoading ? .secondary : color)
				
				VStack(alignment: .leading, spacing: 2) {
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
			.padding(16)
			.background(Color(.systemBackground))
			.overlay(
				RoundedRectangle(cornerRadius: 12)
					.stroke(Color(.systemGray4), lineWidth: 0.5)
			)
			.cornerRadius(12)
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
