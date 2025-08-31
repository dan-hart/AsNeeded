//
//  FeedbackService.swift
//  AsNeeded
//
//  Centralized feedback service with log collection and email composition
//

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
            • iOS Version: \(UIDevice.current.systemVersion)
            • Device Model: \(UIDevice.current.model)
            
            Application logs are attached to help diagnose the issue.
            """
        case .featureRequest:
            return """
            Feature Request
            
            Please describe the feature you would like to see:
            
            
            Use case:
            
            
            Additional context:
            
            
            Device Information:
            • App Version: \(Bundle.main.appVersionLong)
            • iOS Version: \(UIDevice.current.systemVersion)
            • Device Model: \(UIDevice.current.model)
            
            Application logs are attached for context.
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
            • iOS Version: \(UIDevice.current.systemVersion)
            • Device Model: \(UIDevice.current.model)
            
            Application logs are attached for context.
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
    @Published var showingMailComposer = false
    @Published var showingMailUnavailableAlert = false
    
    private var currentFeedbackType: FeedbackType = .feedback
    private var logsZipData: Data?
    
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
            logWarning("Mail not available on device")
            showingMailUnavailableAlert = true
            return
        }
        
        Task {
            await collectAndAttachLogs()
        }
    }
    
    private func collectAndAttachLogs() async {
        isCollectingLogs = true
        logInfo("Collecting application logs")
        
        do {
            let logData = try await collectSystemLogs()
            let combinedData = try createLogsAttachment(with: logData)
            
            logsZipData = combinedData
            showingMailComposer = true
            
            logInfo("Log collection completed successfully")
        } catch {
            logError("Failed to collect logs", error: error)
        }
        
        isCollectingLogs = false
    }
    
    private func collectSystemLogs() async throws -> Data {
        let store = try OSLogStore(scope: .currentProcessIdentifier)
        let position = store.position(timeIntervalSinceLatestBoot: -3600) // Last hour
        
        let entries = try store.getEntries(at: position)
            .compactMap { $0 as? OSLogEntryLog }
            .filter { entry in
                // Filter for our app's logs
                entry.subsystem.contains(Bundle.main.bundleIdentifier ?? "asneeded") ||
                entry.category.contains("DHLogging") ||
                entry.category.contains("AsNeeded")
            }
        
        let logContent = entries.map { entry in
            let timestamp = ISO8601DateFormatter().string(from: entry.date)
            return "[\(timestamp)] [\(entry.level)] [\(entry.category)] \(entry.composedMessage)"
        }.joined(separator: "\n")
        
        return logContent.data(using: .utf8) ?? Data()
    }
    
    private func createLogsAttachment(with logData: Data) throws -> Data {
        let systemInfo = generateSystemInfo()
        let _ = systemInfo.data(using: .utf8) ?? Data()
        
        // Create a simple archive format with both files
        let combinedContent = """
            ===== SYSTEM INFORMATION =====
            \(systemInfo)
            
            ===== APPLICATION LOGS =====
            \(String(data: logData, encoding: .utf8) ?? "Failed to decode log data")
            """
        
        return combinedContent.data(using: .utf8) ?? Data()
    }
    
    private func generateSystemInfo() -> String {
        return """
        AsNeeded System Information
        ===========================
        
        App Information:
        • App Version: \(Bundle.main.appVersionLong)
        • Bundle ID: \(Bundle.main.bundleIdentifier ?? "Unknown")
        • Build Number: \(Bundle.main.buildNumber ?? "Unknown")
        
        Device Information:
        • Device Model: \(UIDevice.current.model)
        • System Name: \(UIDevice.current.systemName)
        • System Version: \(UIDevice.current.systemVersion)
        • Device Name: \(UIDevice.current.name)
        
        Hardware Information:
        • Screen Scale: \(UIScreen.main.scale)x
        • Screen Bounds: \(UIScreen.main.bounds)
        • Available Memory: \(ProcessInfo.processInfo.physicalMemory / 1024 / 1024) MB
        
        Locale Information:
        • Language: \(Locale.current.language.languageCode?.identifier ?? "Unknown")
        • Region: \(Locale.current.region?.identifier ?? "Unknown")
        • Time Zone: \(TimeZone.current.identifier)
        
        Generated: \(ISO8601DateFormatter().string(from: Date()))
        """
    }
    
    func createMailComposer() -> MFMailComposeViewController {
        let composer = MFMailComposeViewController()
        composer.mailComposeDelegate = self
        composer.setToRecipients([supportEmail])
        composer.setSubject(currentFeedbackType.subject)
        composer.setMessageBody(currentFeedbackType.emailBody, isHTML: false)
        
        // Attach logs if available
        if let logsData = logsZipData {
            composer.addAttachmentData(logsData,
                                     mimeType: "text/plain",
                                     fileName: "AsNeeded_Logs.txt")
        }
        
        return composer
    }
}

extension FeedbackService: @preconcurrency MFMailComposeViewControllerDelegate {
    @MainActor
    func mailComposeController(_ controller: MFMailComposeViewController,
                              didFinishWith result: MFMailComposeResult,
                              error: Error?) {
        
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
