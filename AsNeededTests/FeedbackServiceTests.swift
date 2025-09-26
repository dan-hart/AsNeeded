import Testing
import Foundation
@testable import AsNeeded

@MainActor
struct FeedbackServiceTests {

	// MARK: - Feedback Type Tests

	@Test("FeedbackType subjects are correctly formatted")
	func feedbackTypeSubjectsAreCorrect() {
		#expect(FeedbackType.bug.subject == "[BUG]")
		#expect(FeedbackType.featureRequest.subject == "[FEATURE_REQUEST]")
		#expect(FeedbackType.feedback.subject == "[FEEDBACK]")
	}

	@Test("FeedbackType email bodies contain expected content")
	func feedbackTypeEmailBodiesContainExpectedContent() {
		let bugBody = FeedbackType.bug.emailBody
		let featureBody = FeedbackType.featureRequest.emailBody
		let feedbackBody = FeedbackType.feedback.emailBody

		// Bug report specific content
		#expect(bugBody.contains("Bug Report"))
		#expect(bugBody.contains("Steps to reproduce:"))
		#expect(bugBody.contains("Expected behavior:"))

		// Feature request specific content
		#expect(featureBody.contains("Feature Request"))
		#expect(featureBody.contains("What feature would you like to see?"))
		#expect(featureBody.contains("How would this help you?"))

		// General feedback specific content
		#expect(feedbackBody.contains("General Feedback"))
		#expect(feedbackBody.contains("What do you like about AsNeeded?"))
		#expect(feedbackBody.contains("What could be improved?"))

		// All should contain device information
		#expect(bugBody.contains("Device Information:"))
		#expect(featureBody.contains("Device Information:"))
		#expect(feedbackBody.contains("Device Information:"))
	}

	// MARK: - Alternative Feedback Methods Tests

	@Test("createFeedbackText generates properly formatted content")
	func createFeedbackTextGeneratesProperlyFormattedContent() {
		let service = FeedbackService.shared
		let feedbackText = service.createFeedbackText(type: .bug)

		#expect(feedbackText.contains("To: asneeded@codedbydan.com"))
		#expect(feedbackText.contains("Subject: [BUG] AsNeeded App Feedback"))
		#expect(feedbackText.contains("Bug Report"))
		#expect(feedbackText.contains("Device Information:"))
	}

	@Test("createMailtoURL generates valid URLs")
	func createMailtoURLGeneratesValidURLs() {
		let service = FeedbackService.shared
		let url = service.createMailtoURL(type: .bug)

		#expect(url != nil)
		if let url = url {
			#expect(url.scheme == "mailto")
			#expect(url.absoluteString.contains("asneeded@codedbydan.com"))
		}
	}

	@Test("createShareData returns proper subject and text")
	func createShareDataReturnsProperSubjectAndText() {
		let service = FeedbackService.shared
		let shareData = service.createShareData(type: .featureRequest)

		#expect(shareData.subject == "[FEATURE_REQUEST] AsNeeded App Feedback")
		#expect(shareData.text.contains("Feature Request"))
		#expect(shareData.text.contains("asneeded@codedbydan.com"))
	}

	// MARK: - Service State Tests

	@Test("FeedbackService initial state is correct")
	func feedbackServiceInitialStateIsCorrect() {
		let service = FeedbackService.shared

		#expect(service.isCollectingLogs == false)
		#expect(service.showingMailComposer == false)
		#expect(service.showingFeedbackAlternatives == false)
		#expect(service.showingLogConsentDialog == false)
	}
}