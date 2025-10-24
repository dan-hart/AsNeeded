// AppReviewManagerTests.swift
// Unit tests for AppReviewManager opt-out logic

@testable import AsNeeded
import Foundation
import Testing

@MainActor
@Suite("AppReviewManager Review Opt-Out Tests")
struct AppReviewManagerTests {
    // MARK: - Test Setup Helpers

    private func createTestManager() -> AppReviewManager {
        // Reset review preferences before each test
        let manager = AppReviewManager.shared
        manager.resetReviewPreferences()
        manager.resetEngagementTracking()
        return manager
    }

    // MARK: - Opt-Out Preference Tests

    @Test("User can opt out of reviews")
    func userCanOptOut() {
        let manager = createTestManager()

        // Initially not opted out
        #expect(manager.hasOptedOutOfReviews == false, "User should not be opted out by default")

        // Opt out
        manager.hasOptedOutOfReviews = true

        // Verify opt-out persisted
        #expect(manager.hasOptedOutOfReviews == true, "User should be opted out after setting")
    }

    @Test("Reset preferences clears opt-out")
    func resetPreferencesClearsOptOut() {
        let manager = createTestManager()

        // Opt out
        manager.hasOptedOutOfReviews = true
        #expect(manager.hasOptedOutOfReviews == true)

        // Reset
        manager.resetReviewPreferences()

        // Verify opt-out cleared
        #expect(manager.hasOptedOutOfReviews == false, "Opt-out should be cleared after reset")
    }

    // MARK: - Manual Review Request Tests

    @Test("Manual review requests always allowed regardless of opt-out")
    func manualReviewBypassesOptOut() {
        let manager = createTestManager()

        // Opt out of reviews
        manager.hasOptedOutOfReviews = true

        // Manual requests should still be allowed
        #expect(manager.canMakeReviewRequest() == true, "Manual review requests should bypass opt-out")
    }

    @Test("Manual review requests allowed when not opted out")
    func manualReviewWhenNotOptedOut() {
        let manager = createTestManager()

        // Not opted out
        manager.hasOptedOutOfReviews = false

        // Manual requests should be allowed
        #expect(manager.canMakeReviewRequest() == true, "Manual review requests should be allowed when not opted out")
    }

    // MARK: - CTA Visibility Tests

    @Test("Review CTAs always visible via ReviewService")
    func cTAsAlwaysVisible() {
        let manager = createTestManager()
        let reviewService = ReviewService.shared

        // CTAs should be visible when not opted out
        manager.hasOptedOutOfReviews = false
        #expect(reviewService.canShowReviewButtons == true, "CTAs should be visible when not opted out")

        // CTAs should still be visible when opted out
        manager.hasOptedOutOfReviews = true
        #expect(reviewService.canShowReviewButtons == true, "CTAs should remain visible even when opted out")
    }

    // MARK: - Engagement Tracking Tests

    @Test("Engagement stats track correctly")
    func engagementTracking() {
        let manager = createTestManager()

        // Record engagement
        manager.recordAppLaunch()
        manager.recordMedicationEvent()

        // Get stats
        let stats = manager.getEngagementStats()

        // Verify tracking
        #expect(stats.launches >= 1, "Launch count should be tracked")
        #expect(stats.events >= 1, "Event count should be tracked")
    }

    @Test("Reset engagement tracking clears all stats")
    func testResetEngagementTracking() {
        let manager = createTestManager()

        // Record engagement
        manager.recordAppLaunch()
        manager.recordMedicationEvent()

        // Reset tracking
        manager.resetEngagementTracking()

        // Get stats
        let stats = manager.getEngagementStats()

        // Verify all cleared
        #expect(stats.launches == 0, "Launches should be 0 after reset")
        #expect(stats.events == 0, "Events should be 0 after reset")
        #expect(stats.consecutiveDays == 0, "Consecutive days should be 0 after reset")
    }

    // MARK: - Consecutive Days Tracking Tests

    @Test("Consecutive days tracking starts at 1 on first use")
    func consecutiveDaysInitial() {
        let manager = createTestManager()

        // First app launch
        manager.recordAppLaunch()

        // Check consecutive days
        let stats = manager.getEngagementStats()
        #expect(stats.consecutiveDays == 1, "Consecutive days should be 1 on first use")
    }

    // MARK: - Integration Tests

    @Test("Complete opt-out flow preserves manual review access")
    func completeOptOutFlow() {
        let manager = createTestManager()
        let reviewService = ReviewService.shared

        // Initial state: not opted out
        #expect(manager.hasOptedOutOfReviews == false)
        #expect(reviewService.canShowReviewButtons == true)
        #expect(manager.canMakeReviewRequest() == true)

        // User opts out
        manager.hasOptedOutOfReviews = true

        // Verify: CTAs still visible, manual requests still allowed
        #expect(reviewService.canShowReviewButtons == true, "CTAs should remain visible after opt-out")
        #expect(manager.canMakeReviewRequest() == true, "Manual requests should still work after opt-out")
    }

    @Test("Engagement stats persist across opt-out changes")
    func engagementPersistsAcrossOptOut() {
        let manager = createTestManager()

        // Record engagement
        manager.recordAppLaunch()
        manager.recordAppLaunch()
        manager.recordMedicationEvent()

        // Get initial stats
        let initialStats = manager.getEngagementStats()
        let initialLaunches = initialStats.launches
        let initialEvents = initialStats.events

        // Opt out and back in
        manager.hasOptedOutOfReviews = true
        manager.hasOptedOutOfReviews = false

        // Get final stats
        let finalStats = manager.getEngagementStats()

        // Verify stats unchanged by opt-out
        #expect(finalStats.launches == initialLaunches, "Launch count should persist through opt-out changes")
        #expect(finalStats.events == initialEvents, "Event count should persist through opt-out changes")
    }

    @Test("Review service always returns true for CTA visibility")
    func reviewServiceCTAVisibility() {
        let reviewService = ReviewService.shared

        // Should always return true
        #expect(reviewService.canShowReviewButtons == true, "Review service should always show CTAs")

        // Even after multiple checks
        _ = reviewService.canShowReviewButtons
        _ = reviewService.canShowReviewButtons
        #expect(reviewService.canShowReviewButtons == true, "Review service should consistently show CTAs")
    }
}
