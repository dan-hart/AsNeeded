// Bundle+Environment.swift
// Extension to detect app distribution type (Debug, TestFlight, or App Store)

import Foundation

extension Bundle {
    /// Determines if the app is running from TestFlight
    ///
    /// TestFlight builds have a sandbox receipt but no embedded provisioning profile.
    /// This distinguishes them from both Debug builds (have provisioning profile) and
    /// App Store builds (have production receipt).
    var isTestFlight: Bool {
        // Construct path to sandbox receipt (avoiding deprecated appStoreReceiptURL)
        let sandboxReceiptURL = bundleURL
            .appendingPathComponent("StoreKit")
            .appendingPathComponent("sandboxReceipt")

        // Check if sandbox receipt exists (indicates TestFlight or Debug)
        let isSandbox = FileManager.default.fileExists(atPath: sandboxReceiptURL.path)

        // Check for embedded provisioning profile (indicates development/ad-hoc)
        let hasEmbeddedProfile = path(forResource: "embedded", ofType: "mobileprovision") != nil

        // TestFlight = sandbox receipt WITHOUT embedded profile
        return isSandbox && !hasEmbeddedProfile
    }

    /// Represents the app's current distribution configuration
    enum AppConfiguration {
        case debug
        case testFlight
        case appStore

        /// Human-readable description of the distribution type
        var description: String {
            switch self {
            case .debug:
                return "Debug"
            case .testFlight:
                return "TestFlight"
            case .appStore:
                return "App Store"
            }
        }
    }

    /// Returns the current app configuration/distribution type
    var appConfiguration: AppConfiguration {
        #if DEBUG
            return .debug
        #else
            if isTestFlight {
                return .testFlight
            } else {
                return .appStore
            }
        #endif
    }

    /// User-friendly string describing the distribution type
    var distributionType: String {
        appConfiguration.description
    }
}
