//
//  FeedbackService.swift
//  AsNeeded
//
//  Centralized feedback service with log collection and email composition
//

import DHLoggingKit
import Foundation
import MessageUI
import OSLog
import UIKit

enum FeedbackType {
    case bug
    case featureRequest
    case feedback

    var subject: String {
        switch self {
        case .bug:
            return "[BUG]"
        case .featureRequest:
            return "[FEATURE_REQUEST]"
        case .feedback:
            return "[FEEDBACK]"
        }
    }

    @MainActor
    var emailBody: String {
        switch self {
        case .bug:
            return """
            Bug Report

            Please describe the bug you encountered:


            Steps to reproduce:
            1. 
            2. 
            3. 

            Expected behavior:


            Actual behavior:


            Device Information:
            • App Version: \(Bundle.main.appVersionLong)
            • Distribution: \(Bundle.main.distributionType)
            • iOS Version: \(UIDevice.current.systemVersion)
            • Device Model: \(UIDevice.current.model)

            Application logs may be attached to help diagnose the issue.
            No medication names are stored in logs - only technical information.
            """
        case .featureRequest:
            return """
            Feature Request

            Please describe the feature you would like to see:


            Use case:


            Additional context:


            Device Information:
            • App Version: \(Bundle.main.appVersionLong)
            • Distribution: \(Bundle.main.distributionType)
            • iOS Version: \(UIDevice.current.systemVersion)
            • Device Model: \(UIDevice.current.model)

            Application logs may be attached for context.
            No medication names are stored in logs - only technical information.
            """
        case .feedback:
            return """
            General Feedback

            Please share your feedback:


            What do you like most about the app?


            What could be improved?


            Additional comments:


            Device Information:
            • App Version: \(Bundle.main.appVersionLong)
            • Distribution: \(Bundle.main.distributionType)
            • iOS Version: \(UIDevice.current.systemVersion)
            • Device Model: \(UIDevice.current.model)

            Application logs may be attached for context.
            No medication names are stored in logs - only technical information.
            """
        }
    }
}

@MainActor
final class FeedbackService: NSObject, ObservableObject {
    static let shared = FeedbackService()

    private let osLogger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.asneeded", category: "feedback")

    private let supportEmail = "asneeded@codedbydan.com"

    @Published var isCollectingLogs = false
    @Published var isPreparingFeedback = false
    @Published var showingMailComposer = false
    @Published var showingLogConsentDialog = false
    @Published var showingFeedbackAlternatives = false

    private var currentFeedbackType: FeedbackType = .feedback
    private var logsZipData: Data?
    private var pendingFeedbackAction: (() -> Void)?

    override init() {
        super.init()
    }

    private func logInfo(_ message: String) {
        osLogger.info("\(message, privacy: .public)")
    }

    private func logWarning(_ message: String) {
        osLogger.warning("\(message, privacy: .public)")
    }

    private func logError(_ message: String, error: Error? = nil) {
        if let error {
            osLogger.error("\(message, privacy: .public) - Error: \(String(describing: error), privacy: .public)")
        } else {
            osLogger.error("\(message, privacy: .public)")
        }
    }

    func submitFeedback(type: FeedbackType) {
        logInfo("Starting feedback submission: \(type.subject)")
        currentFeedbackType = type

        guard MFMailComposeViewController.canSendMail() else {
            logWarning("Mail not available on device - showing alternatives")
            showingFeedbackAlternatives = true
            return
        }

        // Store the action to perform after user consent
        pendingFeedbackAction = { [weak self] in
            Task { @MainActor in
                await self?.collectAndAttachLogs()
            }
        }

        // Show consent dialog for log sharing
        showingLogConsentDialog = true
    }

    func proceedWithLogs() {
        logInfo("User consented to include logs")
        showingLogConsentDialog = false
        isCollectingLogs = true // Start loading immediately
        pendingFeedbackAction?()
        pendingFeedbackAction = nil
    }

    func proceedWithoutLogs() {
        logInfo("User declined to include logs")
        showingLogConsentDialog = false
        isPreparingFeedback = true
        logsZipData = nil

        // Small delay to ensure smooth transition
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
            showingMailComposer = true
            isPreparingFeedback = false
        }
        pendingFeedbackAction = nil
    }

    private func collectAndAttachLogs() async {
        isCollectingLogs = true // Ensure loading state (also set in proceedWithLogs for immediate feedback)
        logInfo("Collecting application logs")

        do {
            if #available(iOS 15.0, *) {
                let logData = try await DHLoggingKit.exporter.exportLogs(timeInterval: 3600) // Last hour
                logsZipData = logData
            } else {
                logInfo("Log export not available on this iOS version (requires iOS 15.0+)")
                let systemVersion = UIDevice.current.systemVersion
                logsZipData = "Log export requires iOS 15.0 or later. This device is running iOS \(systemVersion).".data(using: .utf8)
            }
            showingMailComposer = true
            logInfo("Log collection completed successfully")
        } catch {
            logError("Failed to collect logs", error: error)
            // Still show mail composer even if log collection fails
            showingMailComposer = true
        }

        isCollectingLogs = false
    }

    func createMailComposer() -> MFMailComposeViewController {
        let composer = MFMailComposeViewController()
        composer.mailComposeDelegate = self
        composer.setToRecipients([supportEmail])
        composer.setSubject(currentFeedbackType.subject)
        composer.setMessageBody(currentFeedbackType.emailBody, isHTML: false)

        // Attach logs if available and user consented
        if let logsData = logsZipData {
            composer.addAttachmentData(logsData,
                                       mimeType: "text/plain",
                                       fileName: "AsNeeded_Logs_\(currentFeedbackType.subject).txt")
        }

        return composer
    }
}

extension FeedbackService: @preconcurrency MFMailComposeViewControllerDelegate {
    @MainActor
    func mailComposeController(_ controller: MFMailComposeViewController,
                               didFinishWith result: MFMailComposeResult,
                               error: Error?)
    {
        switch result {
        case .sent:
            logInfo("Feedback email sent successfully")
        case .cancelled:
            logInfo("Feedback email cancelled")
        case .saved:
            logInfo("Feedback email saved to drafts")
        case .failed:
            logError("Failed to send feedback email", error: error)
        @unknown default:
            logWarning("Unknown mail compose result")
        }

        // Clean up
        logsZipData = nil
        controller.dismiss(animated: true)
    }

    // MARK: - Alternative Feedback Methods

    /// Creates a pre-filled feedback email content for sharing via other apps
    func createFeedbackText(type: FeedbackType) -> String {
        let subject = "\(type.subject) AsNeeded App Feedback"
        let body = type.emailBody
        let deviceInfo = """

        Device Information:
        • App Version: \(Bundle.main.appVersionLong)
        • Distribution: \(Bundle.main.distributionType)
        • iOS Version: \(UIDevice.current.systemVersion)
        • Device Model: \(UIDevice.current.model)
        """

        return """
        To: \(supportEmail)
        Subject: \(subject)

        \(body)\(deviceInfo)
        """
    }

    /// Copies feedback content to clipboard for easy pasting
    func copyFeedbackToClipboard(type: FeedbackType) {
        let feedbackText = createFeedbackText(type: type)
        UIPasteboard.general.string = feedbackText
        logInfo("Feedback copied to clipboard: \(type.subject)")
    }

    /// Copies just the support email address to clipboard
    func copyEmailToClipboard() {
        UIPasteboard.general.string = supportEmail
        logInfo("Support email copied to clipboard")
    }

    /// Creates a mailto URL for opening in any available email app
    func createMailtoURL(type: FeedbackType) -> URL? {
        let subject = "\(type.subject) AsNeeded App Feedback".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let body = type.emailBody.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "mailto:\(supportEmail)?subject=\(subject)&body=\(body)"
        return URL(string: urlString)
    }

    /// Creates a ShareLink-compatible ShareData object
    func createShareData(type: FeedbackType) -> (subject: String, text: String) {
        let subject = "\(type.subject) AsNeeded App Feedback"
        let text = createFeedbackText(type: type)
        return (subject: subject, text: text)
    }
}

enum FeedbackError: Error {
    case zipCreationFailed
    case logCollectionFailed
}

// MARK: - Bundle Extensions

extension Bundle {
    var appVersionLong: String {
        let version = infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let build = infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
        return "\(version) (\(build))"
    }

    var buildNumber: String? {
        return infoDictionary?["CFBundleVersion"] as? String
    }
}
