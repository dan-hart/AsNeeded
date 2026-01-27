// TestTags.swift
// Reusable test tags for categorizing and filtering tests

import Testing

// MARK: - Test Tag Extensions

extension Tag {
    // MARK: - Test Type Tags

    @Tag static var unit: Self
    @Tag static var integration: Self
    @Tag static var performance: Self

    // MARK: - Feature Area Tags

    @Tag static var medication: Self
    @Tag static var search: Self
    @Tag static var navigation: Self
    @Tag static var analytics: Self
    @Tag static var dataStore: Self
    @Tag static var viewModel: Self

    // MARK: - Utility Tags

    @Tag static var utility: Self
    @Tag static var validation: Self
    @Tag static var parser: Self
    @Tag static var formatter: Self
    @Tag static var date: Self

    // MARK: - Data Management Tags

    @Tag static var dataManagement: Self
    @Tag static var persistence: Self
    @Tag static var migration: Self
    @Tag static var compatibility: Self

    // MARK: - UI Component Tags

    @Tag static var ui: Self
    @Tag static var list: Self
    @Tag static var edit: Self
    @Tag static var history: Self
    @Tag static var detail: Self
    @Tag static var trends: Self

    // MARK: - Service Tags

    @Tag static var service: Self
    @Tag static var networking: Self
    @Tag static var rxNorm: Self
    @Tag static var intent: Self
    @Tag static var featureToggle: Self
    @Tag static var fonts: Self
    @Tag static var haptics: Self
    @Tag static var notifications: Self

    // MARK: - Priority Tags

    @Tag static var critical: Self
    @Tag static var smoke: Self
    @Tag static var regression: Self
}
