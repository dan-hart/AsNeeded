import DHLoggingKit
import Foundation

// MARK: - Supporting Types

/// Status of the automatic backup system
enum BackupStatus: Equatable {
    case none
    case success
    case failed(String)
    case bookmarkStale
    case storageFull(bytesNeeded: Int64)
    case accessDenied
}

/// Represents a backup file with metadata
struct BackupFile: Identifiable, Equatable {
    let id: UUID
    let url: URL
    let date: Date
    let size: Int64
    let isValid: Bool

    init(url: URL, date: Date, size: Int64, isValid: Bool) {
        id = UUID()
        self.url = url
        self.date = date
        self.size = size
        self.isValid = isValid
    }
}

/// Errors that can occur during backup operations
enum BackupError: LocalizedError {
    case noLocationConfigured
    case bookmarkStale
    case accessDenied
    case insufficientStorage(bytesNeeded: Int64, bytesAvailable: Int64)
    case validationFailed
    case exportFailed(String)
    case writeFailed(String)

    var errorDescription: String? {
        switch self {
        case .noLocationConfigured:
            return "No backup location configured"
        case .bookmarkStale:
            return "Backup location is no longer accessible"
        case .accessDenied:
            return "Permission denied to access backup location"
        case let .insufficientStorage(needed, available):
            let neededMB = ByteCountFormatter.string(fromByteCount: needed, countStyle: .file)
            let availableMB = ByteCountFormatter.string(fromByteCount: available, countStyle: .file)
            return "Not enough storage space. Need \(neededMB), but only \(availableMB) available"
        case .validationFailed:
            return "Backup file validation failed"
        case let .exportFailed(message):
            return "Export failed: \(message)"
        case let .writeFailed(message):
            return "Write failed: \(message)"
        }
    }
}

/// Manages automatic backup functionality with debouncing and daily cleanup
@MainActor
final class AutomaticBackupManager: ObservableObject {
    // MARK: - Properties

    static let shared = AutomaticBackupManager()

    private let logger = DHLogger(category: "AutomaticBackup")
    private var debounceTask: Task<Void, Never>?
    private let debounceInterval: TimeInterval = 5.0

    @Published var lastBackupDate: Date?
    @Published var lastError: String?
    @Published var lastBackupStatus: BackupStatus = .none
    @Published var isBackupInProgress: Bool = false

    private init() {
        loadLastBackupDate()
    }

    // MARK: - Public Methods

    /// Trigger a backup with 5-second debouncing
    func triggerBackup() {
        guard isEnabled else { return }

        // Cancel any existing debounce task
        debounceTask?.cancel()

        // Create new debounced task
        debounceTask = Task {
            do {
                try await Task.sleep(nanoseconds: UInt64(debounceInterval * 1_000_000_000))

                // Check if task was cancelled during sleep
                guard !Task.isCancelled else { return }

                await performBackup()
            } catch {
                // Task was cancelled or sleep failed
                logger.debug("Debounce task cancelled or failed")
            }
        }
    }

    /// Perform daily cleanup if needed (removes old backup files, keeps only today's)
    func performDailyCleanupIfNeeded() async {
        guard isEnabled else { return }

        let lastCleanupDate = UserDefaults.standard.object(forKey: UserDefaultsKeys.automaticBackupLastCleanupDate) as? Date
        let today = Calendar.current.startOfDay(for: Date())

        // Check if we've already cleaned up today
        if let lastCleanup = lastCleanupDate,
           Calendar.current.isDate(lastCleanup, inSameDayAs: today)
        {
            logger.debug("Cleanup already performed today, skipping")
            return
        }

        await performCleanup()

        // Update last cleanup date
        UserDefaults.standard.set(Date(), forKey: UserDefaultsKeys.automaticBackupLastCleanupDate)
    }

    /// Disable automatic backup and clear bookmark
    func disable() {
        UserDefaults.standard.set(false, forKey: UserDefaultsKeys.automaticBackupEnabled)
        UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.automaticBackupLocationBookmark)
        UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.automaticBackupLastBackupDate)
        UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.automaticBackupLastCleanupDate)
        lastBackupDate = nil
        lastError = nil
        logger.info("Automatic backup disabled and settings cleared")
    }

    /// Save bookmark for selected backup location
    func saveBackupLocation(bookmark: Data) {
        UserDefaults.standard.set(bookmark, forKey: UserDefaultsKeys.automaticBackupLocationBookmark)
        UserDefaults.standard.set(true, forKey: UserDefaultsKeys.automaticBackupEnabled)
        logger.info("Backup location saved and automatic backup enabled")
    }

    /// Perform manual backup immediately (no debouncing)
    /// - Returns: BackupStatus indicating success or failure
    @discardableResult
    func performManualBackup() async -> BackupStatus {
        logger.info("Manual backup requested")
        isBackupInProgress = true
        defer { isBackupInProgress = false }

        await performBackup()
        return lastBackupStatus
    }

    /// Restore data from a backup file
    /// - Parameters:
    ///   - url: URL of the backup file to restore
    ///   - mergeExisting: If true, merge with existing data; if false, replace all data
    /// - Throws: BackupError if restore fails
    func restoreFromBackup(url: URL, mergeExisting: Bool = false) async throws {
        logger.info("Restoring from backup: \(url.lastPathComponent), merge: \(mergeExisting)")

        guard url.startAccessingSecurityScopedResource() else {
            throw BackupError.accessDenied
        }
        defer { url.stopAccessingSecurityScopedResource() }

        // Validate backup before restoring
        guard validateBackup(at: url) else {
            throw BackupError.validationFailed
        }

        do {
            let data = try Data(contentsOf: url)

            // Use existing DataStore import method (DRY!)
            try await DataStore.shared.importDataFromJSON(data, mergeExisting: mergeExisting)

            logger.info("Successfully restored from backup: \(url.lastPathComponent)")
        } catch {
            logger.error("Restore failed: \(error.localizedDescription)")
            throw BackupError.exportFailed(error.localizedDescription)
        }
    }

    /// Clear all automatic backup files
    /// - Throws: BackupError if operation fails
    func clearAllBackups() async throws {
        logger.info("Clearing all automatic backups")

        guard let bookmark = bookmarkData else {
            throw BackupError.noLocationConfigured
        }

        var isStale = false
        guard let backupDirectory = resolveBookmark(bookmark, isStale: &isStale),
              !isStale
        else {
            throw BackupError.bookmarkStale
        }

        guard backupDirectory.startAccessingSecurityScopedResource() else {
            throw BackupError.accessDenied
        }
        defer { backupDirectory.stopAccessingSecurityScopedResource() }

        do {
            let fileManager = FileManager.default
            let contents = try fileManager.contentsOfDirectory(
                at: backupDirectory,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )

            let backupFiles = contents.filter { $0.lastPathComponent.hasPrefix("AsNeeded-AutoBackup-") }

            var deletedCount = 0
            for fileURL in backupFiles {
                try fileManager.removeItem(at: fileURL)
                deletedCount += 1
                logger.debug("Deleted backup: \(fileURL.lastPathComponent)")
            }

            logger.info("Cleared \(deletedCount) backup file(s)")

            // Clear last backup date since no backups exist
            UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.automaticBackupLastBackupDate)
            lastBackupDate = nil
        } catch {
            logger.error("Failed to clear backups: \(error.localizedDescription)")
            throw BackupError.writeFailed(error.localizedDescription)
        }
    }

    // MARK: - Private Methods

    private var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: UserDefaultsKeys.automaticBackupEnabled)
    }

    private var bookmarkData: Data? {
        UserDefaults.standard.data(forKey: UserDefaultsKeys.automaticBackupLocationBookmark)
    }

    private var redactMedicationNames: Bool {
        UserDefaults.standard.bool(forKey: UserDefaultsKeys.automaticBackupRedactMedicationNames)
    }

    private var redactNotes: Bool {
        UserDefaults.standard.bool(forKey: UserDefaultsKeys.automaticBackupRedactNotes)
    }

    private var includeSettings: Bool {
        // Default to true if not explicitly set
        if UserDefaults.standard.object(forKey: UserDefaultsKeys.automaticBackupIncludeSettings) == nil {
            return true
        }
        return UserDefaults.standard.bool(forKey: UserDefaultsKeys.automaticBackupIncludeSettings)
    }

    var retentionDays: Int {
        let days = UserDefaults.standard.integer(forKey: UserDefaultsKeys.automaticBackupRetentionDays)
        return days > 0 ? days : 90 // Default to 90 if not set or invalid
    }

    private func loadLastBackupDate() {
        lastBackupDate = UserDefaults.standard.object(forKey: UserDefaultsKeys.automaticBackupLastBackupDate) as? Date
    }

    private func performBackup() async {
        logger.info("Performing automatic backup (redactNames: \(redactMedicationNames), redactNotes: \(redactNotes), includeSettings: \(includeSettings))")

        guard let bookmark = bookmarkData else {
            let error = "No backup location configured"
            logger.error("\(error)")
            lastError = error
            lastBackupStatus = .failed(error)
            return
        }

        // Resolve security-scoped bookmark and check staleness
        var isStale = false
        guard let backupDirectory = resolveBookmark(bookmark, isStale: &isStale) else {
            let error = "Failed to access backup location"
            logger.error("\(error)")
            lastError = error
            lastBackupStatus = .accessDenied
            return
        }

        // ✅ Check bookmark staleness
        if isStale {
            let error = "Backup location is no longer accessible (bookmark stale)"
            logger.warning("\(error)")
            lastError = error
            lastBackupStatus = .bookmarkStale
            return
        }

        // Start accessing security-scoped resource
        guard backupDirectory.startAccessingSecurityScopedResource() else {
            let error = "Permission denied to access backup location"
            logger.error("\(error)")
            lastError = error
            lastBackupStatus = .accessDenied
            return
        }

        defer {
            backupDirectory.stopAccessingSecurityScopedResource()
        }

        do {
            // ✅ Check available storage space before backup
            let estimatedSize = getEstimatedBackupSize()
            try checkStorageSpace(in: backupDirectory, estimatedSize: estimatedSize)

            // Export data from DataStore (DRY!)
            let exportData = try await DataStore.shared.exportDataAsJSON(
                redactNames: redactMedicationNames,
                redactNotes: redactNotes,
                includeSettings: includeSettings
            )

            // Create filename with today's date
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let dateString = dateFormatter.string(from: Date())
            let filename = "AsNeeded-AutoBackup-\(dateString).json"

            // Write to backup location
            let fileURL = backupDirectory.appendingPathComponent(filename)
            try exportData.write(to: fileURL, options: .atomic)

            // ✅ Validate backup after write
            let isValid = validateBackup(at: fileURL)
            if !isValid {
                logger.error("Backup validation failed, attempting retry")
                // Delete corrupted file
                try? FileManager.default.removeItem(at: fileURL)

                // Retry once without redaction as fallback
                let retryData = try await DataStore.shared.exportDataAsJSON(
                    redactNames: false,
                    redactNotes: false
                )
                try retryData.write(to: fileURL, options: .atomic)

                // Validate retry
                let retryValid = validateBackup(at: fileURL)
                if !retryValid {
                    try FileManager.default.removeItem(at: fileURL)
                    throw BackupError.validationFailed
                }
                logger.info("Backup retry successful")
            }

            logger.info("Automatic backup saved and validated successfully to \(fileURL.path)")

            // Update last backup date and status
            let now = Date()
            UserDefaults.standard.set(now, forKey: UserDefaultsKeys.automaticBackupLastBackupDate)
            lastBackupDate = now
            lastError = nil
            lastBackupStatus = .success

        } catch let error as BackupError {
            let errorMessage = error.errorDescription ?? "Backup failed"
            logger.error("\(errorMessage)")
            lastError = errorMessage

            switch error {
            case let .insufficientStorage(needed, _):
                lastBackupStatus = .storageFull(bytesNeeded: needed)
            case .bookmarkStale:
                lastBackupStatus = .bookmarkStale
            case .accessDenied:
                lastBackupStatus = .accessDenied
            default:
                lastBackupStatus = .failed(errorMessage)
            }
        } catch {
            let errorMessage = "Backup failed: \(error.localizedDescription)"
            logger.error("\(errorMessage)")
            lastError = errorMessage
            lastBackupStatus = .failed(errorMessage)
        }
    }

    private func performCleanup() async {
        logger.info("Performing automatic backup cleanup")

        guard let bookmark = bookmarkData else {
            logger.debug("No backup location configured for cleanup")
            return
        }

        // Resolve security-scoped bookmark
        var isStale = false
        guard let backupDirectory = resolveBookmark(bookmark, isStale: &isStale) else {
            logger.error("Failed to access backup location for cleanup")
            return
        }

        // Start accessing security-scoped resource
        guard backupDirectory.startAccessingSecurityScopedResource() else {
            logger.error("Permission denied to access backup location for cleanup")
            return
        }

        defer {
            backupDirectory.stopAccessingSecurityScopedResource()
        }

        do {
            // Get all backup files
            let fileManager = FileManager.default
            let contents = try fileManager.contentsOfDirectory(
                at: backupDirectory,
                includingPropertiesForKeys: [.creationDateKey],
                options: [.skipsHiddenFiles]
            )

            // Filter for automatic backup files
            let backupFiles = contents.filter { $0.lastPathComponent.hasPrefix("AsNeeded-AutoBackup-") }

            // Calculate cutoff date based on retention policy
            let retention = retentionDays
            let calendar = Calendar.current
            guard let cutoffDate = calendar.date(byAdding: .day, value: -retention, to: Date()) else {
                logger.error("Failed to calculate cutoff date")
                return
            }

            logger.info("Cleaning up backups older than \(retention) days (cutoff: \(cutoffDate))")

            // Get today's date string to always preserve today's backup
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let todayString = dateFormatter.string(from: Date())
            let todayFilename = "AsNeeded-AutoBackup-\(todayString).json"

            // Delete backup files older than retention period (but always keep today's)
            var deletedCount = 0
            for fileURL in backupFiles {
                // Always keep today's backup regardless of retention policy
                if fileURL.lastPathComponent == todayFilename {
                    continue
                }

                // Get file creation date
                guard let values = try? fileURL.resourceValues(forKeys: [.creationDateKey]),
                      let creationDate = values.creationDate
                else {
                    logger.warning("Could not get creation date for \(fileURL.lastPathComponent), skipping")
                    continue
                }

                // Delete if older than cutoff
                if creationDate < cutoffDate {
                    try fileManager.removeItem(at: fileURL)
                    deletedCount += 1
                    logger.debug("Deleted old backup: \(fileURL.lastPathComponent) (created: \(creationDate))")
                }
            }

            logger.info("Cleanup complete: deleted \(deletedCount) old backup file(s), retention policy: \(retention) days")

        } catch {
            logger.error("Cleanup failed: \(error.localizedDescription)")
        }
    }

    private func resolveBookmark(_ bookmark: Data, isStale: inout Bool) -> URL? {
        do {
            let url = try URL(
                resolvingBookmarkData: bookmark,
                options: [],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )

            if isStale {
                logger.warning("Bookmark is stale, may need to re-select location")
            }

            return url
        } catch {
            logger.error("Failed to resolve bookmark: \(error.localizedDescription)")
            return nil
        }
    }

    /// Check if there's enough storage space for a backup
    /// - Parameters:
    ///   - directory: Directory where backup will be saved
    ///   - estimatedSize: Estimated backup size (defaults to 10MB if unknown)
    /// - Returns: True if enough space available
    /// - Throws: BackupError.insufficientStorage if not enough space
    private func checkStorageSpace(in directory: URL, estimatedSize: Int64 = 10_485_760) throws {
        do {
            let values = try directory.resourceValues(forKeys: [.volumeAvailableCapacityKey])
            guard let availableBytes = values.volumeAvailableCapacity else {
                logger.warning("Could not determine available storage space, proceeding anyway")
                return
            }

            // Require at least 1.5x the estimated size for safety
            let requiredBytes = estimatedSize + (estimatedSize / 2)

            if availableBytes < requiredBytes {
                logger.error("Insufficient storage: need \(requiredBytes) bytes, have \(availableBytes) bytes")
                throw BackupError.insufficientStorage(
                    bytesNeeded: requiredBytes,
                    bytesAvailable: Int64(availableBytes)
                )
            }

            logger.debug("Storage check passed: \(availableBytes) bytes available, need \(requiredBytes) bytes")
        } catch let error as BackupError {
            throw error
        } catch {
            logger.warning("Storage check failed with error: \(error.localizedDescription), proceeding anyway")
        }
    }

    /// Get estimated backup size based on previous backups or default
    private func getEstimatedBackupSize() -> Int64 {
        guard let bookmark = bookmarkData else {
            return 10_485_760 // Default 10MB
        }

        var isStale = false
        guard let backupDirectory = resolveBookmark(bookmark, isStale: &isStale),
              !isStale
        else {
            return 10_485_760 // Default 10MB
        }

        // Try to get size of most recent backup file
        guard backupDirectory.startAccessingSecurityScopedResource() else {
            return 10_485_760 // Default 10MB
        }
        defer { backupDirectory.stopAccessingSecurityScopedResource() }

        do {
            let fileManager = FileManager.default
            let contents = try fileManager.contentsOfDirectory(
                at: backupDirectory,
                includingPropertiesForKeys: [.fileSizeKey],
                options: [.skipsHiddenFiles]
            )

            let backupFiles = contents.filter { $0.lastPathComponent.hasPrefix("AsNeeded-AutoBackup-") }
            if let mostRecent = backupFiles.first,
               let values = try? mostRecent.resourceValues(forKeys: [.fileSizeKey]),
               let size = values.fileSize
            {
                logger.debug("Estimated backup size from previous backup: \(size) bytes")
                return Int64(size)
            }
        } catch {
            logger.debug("Could not estimate backup size: \(error.localizedDescription)")
        }

        return 10_485_760 // Default 10MB
    }

    /// Check bookmark staleness and return status
    func checkBookmarkStatus() -> BackupStatus {
        guard let bookmark = bookmarkData else {
            return .none
        }

        var isStale = false
        guard resolveBookmark(bookmark, isStale: &isStale) != nil else {
            return .accessDenied
        }

        if isStale {
            return .bookmarkStale
        }

        return lastBackupStatus
    }

    /// Get backup history (list of all backup files with metadata)
    func getBackupHistory() -> [BackupFile] {
        guard let bookmark = bookmarkData else {
            logger.debug("No bookmark configured for backup history")
            return []
        }

        var isStale = false
        guard let backupDirectory = resolveBookmark(bookmark, isStale: &isStale),
              !isStale
        else {
            logger.warning("Bookmark is stale, cannot get backup history")
            return []
        }

        guard backupDirectory.startAccessingSecurityScopedResource() else {
            logger.error("Permission denied to access backup location for history")
            return []
        }
        defer { backupDirectory.stopAccessingSecurityScopedResource() }

        do {
            let fileManager = FileManager.default
            let contents = try fileManager.contentsOfDirectory(
                at: backupDirectory,
                includingPropertiesForKeys: [.creationDateKey, .fileSizeKey],
                options: [.skipsHiddenFiles]
            )

            let backupFiles = contents
                .filter { $0.lastPathComponent.hasPrefix("AsNeeded-AutoBackup-") }
                .compactMap { url -> BackupFile? in
                    guard let values = try? url.resourceValues(forKeys: [.creationDateKey, .fileSizeKey]),
                          let date = values.creationDate,
                          let size = values.fileSize
                    else {
                        return nil
                    }

                    let isValid = validateBackup(at: url)
                    return BackupFile(url: url, date: date, size: Int64(size), isValid: isValid)
                }
                .sorted { $0.date > $1.date } // Newest first

            logger.debug("Found \(backupFiles.count) backup files")
            return backupFiles
        } catch {
            logger.error("Failed to get backup history: \(error.localizedDescription)")
            return []
        }
    }

    /// Get total size of all backup files
    func getTotalBackupSize() -> Int64 {
        let backupFiles = getBackupHistory()
        return backupFiles.reduce(0) { $0 + $1.size }
    }

    /// Validate a backup file by attempting to decode it
    /// - Parameter url: URL of the backup file to validate
    /// - Returns: True if the backup file is valid and can be decoded
    private func validateBackup(at url: URL) -> Bool {
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            // Decode using same DataExport struct from DataStore (DRY!)
            let backup = try decoder.decode(DataExport.self, from: data)

            // Basic validation: has medications or events
            let isValid = !backup.medications.isEmpty || !backup.events.isEmpty
            if isValid {
                logger.debug("Backup validation successful: \(backup.medications.count) medications, \(backup.events.count) events")
            } else {
                logger.warning("Backup file is empty (no medications or events)")
            }

            return isValid
        } catch {
            logger.error("Backup validation failed: \(error.localizedDescription)")
            return false
        }
    }
}
