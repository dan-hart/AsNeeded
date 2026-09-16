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

    /// `nonisolated` so the off-main file helpers can log without hopping back to the main actor.
    private nonisolated let logger = DHLogger(category: "AutomaticBackup")
    private var debounceTask: Task<Void, Never>?
    private let debounceInterval: TimeInterval = 5.0
    /// Fallback estimate used when there is no previous backup to measure.
    private nonisolated static let defaultEstimatedBackupSize: Int64 = 10_485_760
    /// Prefix shared by every automatic backup filename.
    private nonisolated static let backupFilenamePrefix = "AsNeeded-AutoBackup-"
    /// Last known reachability of the backup folder, plus the bookmark it was resolved from.
    /// `checkBookmarkStatus()` is read while SwiftUI builds the view, so resolving the bookmark there
    /// would put file system work on the main actor for every frame. `refreshBookmarkStatus()` fills
    /// this in off the main actor instead.
    private var cachedBookmarkStatus: BackupStatus?
    private var cachedBookmarkStatusKey: Data?

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
        invalidateBookmarkStatusCache()
        logger.info("Automatic backup disabled and settings cleared")
    }

    /// Save bookmark for selected backup location
    func saveBackupLocation(bookmark: Data) {
        UserDefaults.standard.set(bookmark, forKey: UserDefaultsKeys.automaticBackupLocationBookmark)
        UserDefaults.standard.set(true, forKey: UserDefaultsKeys.automaticBackupEnabled)
        invalidateBookmarkStatusCache()
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
        logger.info("Restoring from backup, merge: \(mergeExisting)")

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

            logger.info("Successfully restored from backup")
        } catch {
            logger.logPrivacySafeError("Restore failed", error: error)
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

        let resolved = await resolveBackupDirectory(bookmark)
        guard let backupDirectory = resolved.url, !resolved.isStale else {
            throw BackupError.bookmarkStale
        }

        guard backupDirectory.startAccessingSecurityScopedResource() else {
            throw BackupError.accessDenied
        }
        defer { backupDirectory.stopAccessingSecurityScopedResource() }

        do {
            // Listing and deleting every backup file runs off the main actor.
            let deletedCount = try await Self.offMain { [self] in
                let fileManager = FileManager.default
                let contents = try fileManager.contentsOfDirectory(
                    at: backupDirectory,
                    includingPropertiesForKeys: nil,
                    options: [.skipsHiddenFiles]
                )

                let backupFiles = contents.filter { $0.lastPathComponent.hasPrefix(Self.backupFilenamePrefix) }

                var deleted = 0
                for fileURL in backupFiles {
                    try fileManager.removeItem(at: fileURL)
                    deleted += 1
                    logger.debug("Deleted backup")
                }
                return deleted
            }

            logger.info("Cleared \(deletedCount) backup file(s)")

            // Clear last backup date since no backups exist
            UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.automaticBackupLastBackupDate)
            lastBackupDate = nil
        } catch {
            logger.logPrivacySafeError("Failed to clear backups", error: error)
            throw BackupError.writeFailed(error.localizedDescription)
        }
    }

    // MARK: - Off-Main File Work
    /// Runs blocking file work off the main actor and returns its result.
    ///
    /// The backup folder normally lives in iCloud Drive or another Files provider, where a single read,
    /// write or directory listing can take seconds. Any of that on the main actor freezes the whole UI,
    /// which is what made picking a backup location look like a hang. `Task.detached` is used instead of
    /// a plain `nonisolated` async function because approachable concurrency keeps those on the caller's
    /// actor, which would leave the work on the main thread.
    private static func offMain<T: Sendable>(
        _ work: @escaping @Sendable () throws -> T
    ) async throws -> T {
        try await Task.detached(priority: .userInitiated, operation: work).value
    }

    /// A resolved backup folder together with whether its bookmark has gone stale.
    private struct ResolvedLocation {
        var url: URL?
        var isStale: Bool
    }

    /// Resolves the backup folder bookmark off the main actor.
    private func resolveBackupDirectory(_ bookmark: Data) async -> ResolvedLocation {
        let resolved = try? await Self.offMain { [self] in
            var isStale = false
            let url = resolveBookmark(bookmark, isStale: &isStale)
            return ResolvedLocation(url: url, isStale: isStale)
        }
        return resolved ?? ResolvedLocation(url: nil, isStale: false)
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
            logger.error("No backup location configured")
            lastError = error
            lastBackupStatus = .failed(error)
            return
        }

        // Resolve security-scoped bookmark and check staleness. Resolving touches the file system, so
        // it runs off the main actor.
        let resolved = await resolveBackupDirectory(bookmark)
        guard let backupDirectory = resolved.url else {
            let error = "Failed to access backup location"
            logger.error("Failed to access backup location")
            lastError = error
            lastBackupStatus = .accessDenied
            return
        }

        // ✅ Check bookmark staleness
        if resolved.isStale {
            let error = "Backup location is no longer accessible (bookmark stale)"
            logger.warning("Backup location is no longer accessible (bookmark stale)")
            lastError = error
            lastBackupStatus = .bookmarkStale
            return
        }

        // Start accessing security-scoped resource
        guard backupDirectory.startAccessingSecurityScopedResource() else {
            let error = "Permission denied to access backup location"
            logger.error("Permission denied to access backup location")
            lastError = error
            lastBackupStatus = .accessDenied
            return
        }

        defer {
            backupDirectory.stopAccessingSecurityScopedResource()
        }

        do {
            // ✅ Check available storage space before backup. Sizing the previous backup and reading the
            // volume's free space both hit the provider, so they run off the main actor.
            try await Self.offMain { [self] in
                let estimatedSize = estimatedBackupSize(in: backupDirectory)
                try checkStorageSpace(in: backupDirectory, estimatedSize: estimatedSize)
            }

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
            let filename = "\(Self.backupFilenamePrefix)\(dateString).json"

            // Write to backup location, then validate it. An atomic write into a Files provider is the
            // slowest step in a backup and reading it back to validate is a close second, so both are
            // kept off the main actor.
            let fileURL = backupDirectory.appendingPathComponent(filename)
            let isValid = try await Self.offMain { [self] in
                try exportData.write(to: fileURL, options: .atomic)
                // ✅ Validate backup after write
                return validateBackup(at: fileURL)
            }

            if !isValid {
                logger.error("Backup validation failed, attempting retry")

                // Retry once without redaction as fallback
                let retryData = try await DataStore.shared.exportDataAsJSON(
                    redactNames: false,
                    redactNotes: false
                )

                let retryValid = try await Self.offMain { [self] in
                    // Delete corrupted file
                    try? FileManager.default.removeItem(at: fileURL)
                    try retryData.write(to: fileURL, options: .atomic)
                    // Validate retry
                    return validateBackup(at: fileURL)
                }

                if !retryValid {
                    try await Self.offMain { try FileManager.default.removeItem(at: fileURL) }
                    throw BackupError.validationFailed
                }
                logger.info("Backup retry successful")
            }

            logger.info("Automatic backup saved and validated successfully")

            // Update last backup date and status
            let now = Date()
            UserDefaults.standard.set(now, forKey: UserDefaultsKeys.automaticBackupLastBackupDate)
            lastBackupDate = now
            lastError = nil
            lastBackupStatus = .success
            cachedBookmarkStatusKey = bookmark
            cachedBookmarkStatus = .success

        } catch let error as BackupError {
            let errorMessage = error.errorDescription ?? "Backup failed"
            logger.logPrivacySafeError("Automatic backup failed", error: error)
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
            logger.logPrivacySafeError("Automatic backup failed", error: error)
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

        // Resolve security-scoped bookmark off the main actor; cleanup runs at launch and must not
        // delay the first frame.
        guard let backupDirectory = await resolveBackupDirectory(bookmark).url else {
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
        let todayFilename = "\(Self.backupFilenamePrefix)\(todayString).json"

        do {
            // Listing the folder and deleting expired files runs off the main actor.
            let deletedCount = try await Self.offMain { [self] in
                // Get all backup files
                let fileManager = FileManager.default
                let contents = try fileManager.contentsOfDirectory(
                    at: backupDirectory,
                    includingPropertiesForKeys: [.creationDateKey],
                    options: [.skipsHiddenFiles]
                )

                // Filter for automatic backup files
                let backupFiles = contents.filter { $0.lastPathComponent.hasPrefix(Self.backupFilenamePrefix) }

                // Delete backup files older than retention period (but always keep today's)
                var deleted = 0
                for fileURL in backupFiles {
                    // Always keep today's backup regardless of retention policy
                    if fileURL.lastPathComponent == todayFilename {
                        continue
                    }

                    // Get file creation date
                    guard let values = try? fileURL.resourceValues(forKeys: [.creationDateKey]),
                          let creationDate = values.creationDate
                    else {
                        logger.warning("Could not get backup creation date, skipping")
                        continue
                    }

                    // Delete if older than cutoff
                    if creationDate < cutoffDate {
                        try fileManager.removeItem(at: fileURL)
                        deleted += 1
                        logger.debug("Deleted old backup")
                    }
                }
                return deleted
            }

            logger.info("Cleanup complete: deleted \(deletedCount) old backup file(s), retention policy: \(retention) days")

        } catch {
            logger.logPrivacySafeError("Cleanup failed", error: error)
        }
    }

    /// `nonisolated` so it can be called from `offMain`; it touches no actor-isolated state.
    private nonisolated func resolveBookmark(_ bookmark: Data, isStale: inout Bool) -> URL? {
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
            logger.logPrivacySafeError("Failed to resolve bookmark", error: error)
            return nil
        }
    }

    /// Check if there's enough storage space for a backup
    /// - Parameters:
    ///   - directory: Directory where backup will be saved
    ///   - estimatedSize: Estimated backup size (defaults to 10MB if unknown)
    /// - Returns: True if enough space available
    /// - Throws: BackupError.insufficientStorage if not enough space
    private nonisolated func checkStorageSpace(in directory: URL, estimatedSize: Int64) throws {
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
            logger.logPrivacySafeWarning("Storage check failed, proceeding anyway", error: error)
        }
    }

    /// Estimated size of the next backup, taken from the newest existing backup file.
    ///
    /// Takes the already-resolved folder so it never resolves the bookmark or re-acquires security-scoped
    /// access a second time, and is `nonisolated` so the directory listing can run off the main actor.
    /// The caller must already hold access to `backupDirectory`.
    private nonisolated func estimatedBackupSize(in backupDirectory: URL) -> Int64 {
        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: backupDirectory,
                includingPropertiesForKeys: [.fileSizeKey],
                options: [.skipsHiddenFiles]
            )

            let backupFiles = contents.filter { $0.lastPathComponent.hasPrefix(Self.backupFilenamePrefix) }
            if let mostRecent = backupFiles.first,
               let values = try? mostRecent.resourceValues(forKeys: [.fileSizeKey]),
               let size = values.fileSize
            {
                logger.debug("Estimated backup size from previous backup: \(size) bytes")
                return Int64(size)
            }
        } catch {
            logger.logPrivacySafeDebug("Could not estimate backup size", error: error)
        }

        return Self.defaultEstimatedBackupSize
    }

    /// Last known bookmark staleness, without touching the file system.
    ///
    /// SwiftUI reads this while building the backup screen, so it must never resolve the bookmark itself.
    /// Until `refreshBookmarkStatus()` has run it falls back to the last recorded backup status.
    func checkBookmarkStatus() -> BackupStatus {
        guard let bookmark = bookmarkData else {
            return .none
        }

        guard cachedBookmarkStatusKey == bookmark, let cached = cachedBookmarkStatus else {
            return lastBackupStatus
        }

        // A reachable location reports whatever the last backup did; only problems override it.
        if cached == .success {
            return lastBackupStatus
        }
        return cached
    }

    /// Resolves the bookmark off the main actor and caches whether the backup folder is still reachable.
    func refreshBookmarkStatus() async {
        guard let bookmark = bookmarkData else {
            invalidateBookmarkStatusCache()
            return
        }

        let resolved = await resolveBackupDirectory(bookmark)
        cachedBookmarkStatusKey = bookmark
        if resolved.url == nil {
            cachedBookmarkStatus = .accessDenied
        } else if resolved.isStale {
            cachedBookmarkStatus = .bookmarkStale
        } else {
            cachedBookmarkStatus = .success
        }
    }

    /// Display name of the configured backup folder, resolved off the main actor.
    func backupLocationName() async -> String? {
        guard let bookmark = bookmarkData else {
            return nil
        }
        return await resolveBackupDirectory(bookmark).url?.lastPathComponent
    }

    private func invalidateBookmarkStatusCache() {
        cachedBookmarkStatusKey = nil
        cachedBookmarkStatus = nil
    }

    /// Backup files at the configured location, newest first.
    ///
    /// Listing the folder and reading every file back to check it decodes is the single most expensive
    /// thing this class does, so all of it runs off the main actor. Callers derive the total size from
    /// the returned array rather than asking for a second scan.
    func backupHistory() async -> [BackupFile] {
        guard let bookmark = bookmarkData else {
            logger.debug("No bookmark configured for backup history")
            return []
        }

        let files = try? await Self.offMain { [self] in
            var isStale = false
            guard let backupDirectory = resolveBookmark(bookmark, isStale: &isStale), !isStale else {
                logger.warning("Bookmark is stale, cannot get backup history")
                return [BackupFile]()
            }

            guard backupDirectory.startAccessingSecurityScopedResource() else {
                logger.error("Permission denied to access backup location for history")
                return [BackupFile]()
            }
            defer { backupDirectory.stopAccessingSecurityScopedResource() }

            return scanBackupFiles(in: backupDirectory)
        }

        return files ?? []
    }

    /// Lists and validates the backup files in an already-accessible folder.
    /// `nonisolated` so `backupHistory()` can run it off the main actor.
    private nonisolated func scanBackupFiles(in backupDirectory: URL) -> [BackupFile] {
        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: backupDirectory,
                includingPropertiesForKeys: [.creationDateKey, .fileSizeKey],
                options: [.skipsHiddenFiles]
            )

            let backupFiles = contents
                .filter { $0.lastPathComponent.hasPrefix(Self.backupFilenamePrefix) }
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
            logger.logPrivacySafeError("Failed to get backup history", error: error)
            return []
        }
    }

    /// Validate a backup file by attempting to decode it
    /// - Parameter url: URL of the backup file to validate
    /// - Returns: True if the backup file is valid and can be decoded
    private nonisolated func validateBackup(at url: URL) -> Bool {
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
            logger.logPrivacySafeError("Backup validation failed", error: error)
            return false
        }
    }
}
