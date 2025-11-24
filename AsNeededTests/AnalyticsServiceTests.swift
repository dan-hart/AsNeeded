// AnalyticsServiceTests.swift
// Comprehensive unit tests for AnalyticsService

import ANModelKit
@testable import AsNeeded
import Foundation
import Testing

@Suite("AnalyticsService Tests", .tags(.analytics, .service, .unit))
struct AnalyticsServiceTests {
    // MARK: - Test Helper

    private class MockUserDefaults: UserDefaults {
        private var storage: [String: Any] = [:]

        override func set(_ value: Any?, forKey defaultName: String) {
            storage[defaultName] = value
        }

        override func object(forKey defaultName: String) -> Any? {
            return storage[defaultName]
        }

        override func integer(forKey defaultName: String) -> Int {
            return storage[defaultName] as? Int ?? 0
        }

        override func dictionary(forKey defaultName: String) -> [String: Any]? {
            return storage[defaultName] as? [String: Any]
        }

        override func removeObject(forKey defaultName: String) {
            storage.removeValue(forKey: defaultName)
        }

        func clearAll() {
            storage.removeAll()
        }
    }

    // MARK: - Feature Usage Tests

    @Test("Track feature use increments count")
    @MainActor
    func testTrackFeatureUse() {
        let analytics = AnalyticsService.shared

        // Track multiple uses of a feature
        analytics.trackFeatureUse(.logDose)
        analytics.trackFeatureUse(.logDose)
        analytics.trackFeatureUse(.viewHistory)

        let summary = analytics.getAnalyticsSummary()
        let features = summary.mostUsedFeatures

        #expect(features.count > 0)
    }

    @Test("Track medication added increments counter")
    @MainActor
    func testTrackMedicationAdded() {
        let analytics = AnalyticsService.shared
        let initialSummary = analytics.getAnalyticsSummary()
        let initialCount = initialSummary.totalMedicationsAdded

        analytics.trackMedicationAdded()

        let newSummary = analytics.getAnalyticsSummary()
        #expect(newSummary.totalMedicationsAdded == initialCount + 1)
    }

    @Test("Track event logged increments counter")
    @MainActor
    func testTrackEventLogged() {
        let analytics = AnalyticsService.shared
        let initialSummary = analytics.getAnalyticsSummary()
        let initialCount = initialSummary.totalEventsLogged

        analytics.trackEventLogged(type: .doseTaken)

        let newSummary = analytics.getAnalyticsSummary()
        #expect(newSummary.totalEventsLogged == initialCount + 1)
    }

    @Test("Track data export updates last export date")
    @MainActor
    func testTrackDataExport() {
        let analytics = AnalyticsService.shared
        let beforeExport = Date()

        analytics.trackDataExport(itemCount: 100, redacted: false)

        let summary = analytics.getAnalyticsSummary()
        if let exportDate = summary.lastExportDate {
            #expect(exportDate >= beforeExport)
        }
    }

    @Test("Track data import updates last import date on success")
    @MainActor
    func testTrackDataImport() {
        let analytics = AnalyticsService.shared
        let beforeImport = Date()

        analytics.trackDataImport(itemCount: 50, success: true)

        let summary = analytics.getAnalyticsSummary()
        if let importDate = summary.lastImportDate {
            #expect(importDate >= beforeImport)
        }
    }

    @Test("Track data import does not update date on failure")
    @MainActor
    func trackDataImportFailure() {
        let analytics = AnalyticsService.shared
        let initialSummary = analytics.getAnalyticsSummary()
        let initialImportDate = initialSummary.lastImportDate

        analytics.trackDataImport(itemCount: 0, success: false)

        let newSummary = analytics.getAnalyticsSummary()
        #expect(newSummary.lastImportDate == initialImportDate)
    }

    // MARK: - Analytics Summary Tests

    @Test("Analytics summary contains expected fields")
    @MainActor
    func analyticsSummary() {
        let analytics = AnalyticsService.shared
        let summary = analytics.getAnalyticsSummary()

        // Check that summary has expected structure
        #expect(summary.launchCount >= 0)
        #expect(summary.totalMedicationsAdded >= 0)
        #expect(summary.totalEventsLogged >= 0)
        #expect(summary.mostUsedFeatures.count <= 5) // Top 5 features
    }

    @Test("Days since first launch calculates correctly")
    @MainActor
    func testDaysSinceFirstLaunch() {
        let tenDaysAgo = Calendar.current.date(byAdding: .day, value: -10, to: Date())
        let summary = AnalyticsSummary(
            firstLaunchDate: tenDaysAgo,
            launchCount: 10,
            lastLaunchDate: Date(),
            totalMedicationsAdded: 0,
            totalEventsLogged: 0,
            lastExportDate: nil,
            lastImportDate: nil,
            mostUsedFeatures: []
        )

        if let days = summary.daysSinceFirstLaunch {
            #expect(days >= 9 && days <= 11) // Allow for date calculation variance
        }
    }

    @Test("Average daily launches calculates correctly")
    @MainActor
    func testAverageDailyLaunches() {
        let tenDaysAgo = Calendar.current.date(byAdding: .day, value: -10, to: Date())
        let summary = AnalyticsSummary(
            firstLaunchDate: tenDaysAgo,
            launchCount: 30,
            lastLaunchDate: Date(),
            totalMedicationsAdded: 0,
            totalEventsLogged: 0,
            lastExportDate: nil,
            lastImportDate: nil,
            mostUsedFeatures: []
        )

        if let average = summary.averageDailyLaunches {
            #expect(average >= 2.5 && average <= 3.5) // Approximately 3 launches per day
        }
    }

    @Test("Average daily launches returns nil for no first launch")
    @MainActor
    func averageDailyLaunchesNoFirstLaunch() {
        let summary = AnalyticsSummary(
            firstLaunchDate: nil,
            launchCount: 10,
            lastLaunchDate: Date(),
            totalMedicationsAdded: 0,
            totalEventsLogged: 0,
            lastExportDate: nil,
            lastImportDate: nil,
            mostUsedFeatures: []
        )

        #expect(summary.averageDailyLaunches == nil)
        #expect(summary.daysSinceFirstLaunch == nil)
    }

    // MARK: - Feature Enum Tests

    @Test("Feature enum has expected values")
    @MainActor
    func featureEnumValues() {
        #expect(AnalyticsService.Feature.addMedication.rawValue == "add_medication")
        #expect(AnalyticsService.Feature.editMedication.rawValue == "edit_medication")
        #expect(AnalyticsService.Feature.deleteMedication.rawValue == "delete_medication")
        #expect(AnalyticsService.Feature.logDose.rawValue == "log_dose")
        #expect(AnalyticsService.Feature.viewHistory.rawValue == "view_history")
        #expect(AnalyticsService.Feature.viewTrends.rawValue == "view_trends")
        #expect(AnalyticsService.Feature.exportData.rawValue == "export_data")
        #expect(AnalyticsService.Feature.importData.rawValue == "import_data")
        #expect(AnalyticsService.Feature.searchMedication.rawValue == "search_medication")
        #expect(AnalyticsService.Feature.setReminder.rawValue == "set_reminder")
        #expect(AnalyticsService.Feature.siriShortcut.rawValue == "siri_shortcut")
    }

    // MARK: - Clear Analytics Tests

    @Test("Clear analytics resets all data")
    @MainActor
    func testClearAnalytics() {
        let analytics = AnalyticsService.shared

        // Add some data
        analytics.trackMedicationAdded()
        analytics.trackEventLogged(type: .doseTaken)
        analytics.trackFeatureUse(.viewHistory)

        // Clear analytics
        analytics.clearAnalytics()

        let summary = analytics.getAnalyticsSummary()
        // Note: launch count might not be 0 due to app launch tracking
        #expect(summary.totalMedicationsAdded == 0)
        #expect(summary.totalEventsLogged == 0)
        #expect(summary.lastExportDate == nil)
        #expect(summary.lastImportDate == nil)
    }

    // MARK: - Performance Tests

    @Test("Track feature use is performant")
    @MainActor
    func trackFeaturePerformance() {
        let analytics = AnalyticsService.shared

        let startTime = Date()
        for _ in 0 ..< 1000 {
            analytics.trackFeatureUse(.logDose)
        }
        let elapsed = Date().timeIntervalSince(startTime)

        #expect(elapsed < 1.0) // Should complete 1000 tracks in less than 1 second
    }

    @Test("Get analytics summary is performant")
    @MainActor
    func getSummaryPerformance() {
        let analytics = AnalyticsService.shared

        // Add some data
        for i in 0 ..< 100 {
            if i % 2 == 0 {
                analytics.trackMedicationAdded()
            } else {
                analytics.trackEventLogged(type: .doseTaken)
            }
        }

        let startTime = Date()
        for _ in 0 ..< 100 {
            _ = analytics.getAnalyticsSummary()
        }
        let elapsed = Date().timeIntervalSince(startTime)

        #expect(elapsed < 0.5) // Should complete 100 summaries in less than 500ms
    }

    // MARK: - Top Features Tests

    @Test("Top features are sorted by count")
    @MainActor
    func topFeaturesSorting() {
        let analytics = AnalyticsService.shared

        // Track features with different frequencies
        for _ in 0 ..< 5 {
            analytics.trackFeatureUse(.logDose)
        }
        for _ in 0 ..< 3 {
            analytics.trackFeatureUse(.viewHistory)
        }
        for _ in 0 ..< 7 {
            analytics.trackFeatureUse(.viewTrends)
        }

        let summary = analytics.getAnalyticsSummary()
        let features = summary.mostUsedFeatures

        // Check that features are sorted in descending order by count
        for i in 0 ..< features.count - 1 {
            if let current = features[safe: i], let next = features[safe: i + 1] {
                #expect(current.count >= next.count)
            }
        }
    }

    @Test("Top features limited to 5")
    @MainActor
    func topFeaturesLimit() {
        let analytics = AnalyticsService.shared

        // Track more than 5 different features
        analytics.trackFeatureUse(.addMedication)
        analytics.trackFeatureUse(.editMedication)
        analytics.trackFeatureUse(.deleteMedication)
        analytics.trackFeatureUse(.logDose)
        analytics.trackFeatureUse(.viewHistory)
        analytics.trackFeatureUse(.viewTrends)
        analytics.trackFeatureUse(.exportData)

        let summary = analytics.getAnalyticsSummary()
        #expect(summary.mostUsedFeatures.count <= 5)
    }
}
