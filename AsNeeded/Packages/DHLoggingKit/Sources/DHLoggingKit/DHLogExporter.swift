//
//  DHLogExporter.swift
//  DHLoggingKit
//
//  Log collection and export functionality with privacy controls
//

import Foundation
import OSLog

/// Service for collecting and exporting application logs with privacy controls
@available(iOS 15.0, macOS 12.0, watchOS 8.0, tvOS 15.0, visionOS 1.0, *)
public final class DHLogExporter: @unchecked Sendable {
    
    // MARK: - Properties
    private let logger = DHLogger(category: "log-exporter")
    
    // MARK: - Public Interface
    
    /// Gets the count of log entries for the specified time period
    /// - Parameters:
    ///   - timeInterval: How far back to count logs (in seconds). Default is 24 hours
    ///   - bundleIdentifier: Optional bundle identifier to filter logs. Uses main bundle if nil
    /// - Returns: Number of log entries
    public func getLogCount(
        timeInterval: TimeInterval = 86400,
        bundleIdentifier: String? = nil
    ) async -> Int {
        let bundleId = bundleIdentifier ?? Bundle.main.bundleIdentifier ?? "unknown"
        
        do {
            let entries = try await collectLogEntries(
                timeInterval: timeInterval,
                bundleIdentifier: bundleId
            )
            return entries.count
        } catch {
            logger.error("Failed to get log count", error: error)
            return 0
        }
    }
    
    /// Collects and exports application logs for the specified time period
    /// - Parameters:
    ///   - timeInterval: How far back to collect logs (in seconds). Default is 1 hour (3600 seconds)
    ///   - bundleIdentifier: Optional bundle identifier to filter logs. Uses main bundle if nil
    /// - Returns: Exported log data as Data object
    /// - Throws: DHLogExportError if collection fails
    public func exportLogs(
        timeInterval: TimeInterval = 3600,
        bundleIdentifier: String? = nil
    ) async throws -> Data {
        logger.info("Starting log export process")
        
        let bundleId = bundleIdentifier ?? Bundle.main.bundleIdentifier ?? "unknown"
        logger.debug("Collecting logs for bundle: \(bundleId) over last \(timeInterval) seconds")
        
        do {
            let logEntries = try await collectLogEntries(
                timeInterval: timeInterval,
                bundleIdentifier: bundleId
            )
            
            let exportData = try createExportData(from: logEntries, bundleIdentifier: bundleId)
            
            logger.info("Log export completed successfully. Entries: \(logEntries.count)")
            return exportData
        } catch {
            logger.error("Log export failed", error: error)
            throw DHLogExportError.exportFailed(error)
        }
    }
    
    /// Collects and formats logs as a human-readable string
    /// - Parameters:
    ///   - timeInterval: How far back to collect logs (in seconds)
    ///   - bundleIdentifier: Optional bundle identifier to filter logs
    /// - Returns: Formatted log string
    public func exportLogsAsString(
        timeInterval: TimeInterval = 3600,
        bundleIdentifier: String? = nil
    ) async throws -> String {
        let data = try await exportLogs(timeInterval: timeInterval, bundleIdentifier: bundleIdentifier)
        return String(data: data, encoding: .utf8) ?? "Failed to decode log data"
    }
    
    // MARK: - Private Implementation
    
    private func collectLogEntries(
        timeInterval: TimeInterval,
        bundleIdentifier: String
    ) async throws -> [OSLogEntryLog] {
        
        do {
            let store = try OSLogStore(scope: .currentProcessIdentifier)
            let position = store.position(timeIntervalSinceLatestBoot: -timeInterval)
            
            let entries = try store.getEntries(at: position)
                .compactMap { $0 as? OSLogEntryLog }
                .filter { entry in
                    // Filter for our app's logs and DHLoggingKit logs
                    entry.subsystem.contains(bundleIdentifier) ||
                    entry.category.contains("DHLogging") ||
                    entry.subsystem.contains("DHLoggingKit")
                }
                .sorted { $0.date < $1.date } // Sort chronologically
            
            return entries
        } catch {
            throw DHLogExportError.logCollectionFailed(error)
        }
    }
    
    private func createExportData(
        from entries: [OSLogEntryLog],
        bundleIdentifier: String
    ) throws -> Data {
        
        let header = createExportHeader(bundleIdentifier: bundleIdentifier, entryCount: entries.count)
        let privacyNotice = createPrivacyNotice()
        
        let logContent = entries.map { entry in
            formatLogEntry(entry)
        }.joined(separator: "\n")
        
        let fullContent = """
        \(header)
        
        \(privacyNotice)
        
        ===== APPLICATION LOGS =====
        \(logContent)
        """
        
        guard let data = fullContent.data(using: .utf8) else {
            throw DHLogExportError.dataEncodingFailed
        }
        
        return data
    }
    
    private func createExportHeader(bundleIdentifier: String, entryCount: Int) -> String {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        
        return """
        AsNeeded Application Logs Export
        ===============================
        
        Export Information:
        • Generated: \(timestamp)
        • Bundle ID: \(bundleIdentifier)
        • DHLoggingKit Version: \(DHLoggingKit.version)
        • Log Entries: \(entryCount)
        
        Device Information:
        • System: \(ProcessInfo.processInfo.operatingSystemVersionString)
        • App Version: \(Bundle.main.appVersionLong)
        """
    }
    
    private func createPrivacyNotice() -> String {
        return """
        ===== PRIVACY NOTICE =====
        
        IMPORTANT: No medication names are stored in these logs.
        
        This log export contains technical information about app operations, 
        including:
        • General app events (launches, navigation, etc.)
        • Network requests (without personal data)
        • Data operations (counts and types, not content)
        • Error messages and debugging information
        • User interface interactions (general flow only)
        
        All sensitive information including medication names, personal 
        identifiers, and health data has been filtered out or marked 
        as private in accordance with Apple's OSLog privacy controls.
        
        These logs are useful for debugging technical issues but do not 
        contain any personally identifiable health information.
        """
    }
    
    private func formatLogEntry(_ entry: OSLogEntryLog) -> String {
        let timestamp = ISO8601DateFormatter().string(from: entry.date)
        let level = formatLogLevel(entry.level)
        return "[\(timestamp)] [\(level)] [\(entry.category)] \(entry.composedMessage)"
    }
    
    private func formatLogLevel(_ level: OSLogEntryLog.Level) -> String {
        switch level {
        case .debug:
            return "DEBUG"
        case .info:
            return "INFO"
        case .notice:
            return "NOTICE"
        case .error:
            return "ERROR"
        case .fault:
            return "FAULT"
        default:
            return "UNKNOWN"
        }
    }
}

// MARK: - Error Types

public enum DHLogExportError: Error, LocalizedError {
    case logCollectionFailed(Error)
    case dataEncodingFailed
    case exportFailed(Error)
    
    public var errorDescription: String? {
        switch self {
        case .logCollectionFailed(let error):
            return "Failed to collect logs: \(error.localizedDescription)"
        case .dataEncodingFailed:
            return "Failed to encode log data"
        case .exportFailed(let error):
            return "Log export failed: \(error.localizedDescription)"
        }
    }
}

// MARK: - Bundle Extensions (if not already present)
extension Bundle {
    var appVersionLong: String {
        let version = infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let build = infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
        return "\(version) (\(build))"
    }
}