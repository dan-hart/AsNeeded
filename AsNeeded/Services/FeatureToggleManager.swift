import SwiftUI

/// Manages feature toggles for experimental or debug features
@MainActor
final class FeatureToggleManager: ObservableObject {
    static let shared = FeatureToggleManager()

    // Feature Toggle for Quick Phrases - OFF by default
    @AppStorage(UserDefaultsKeys.featureToggleQuickPhrases) public var quickPhrasesEnabled: Bool = false

    /// Determines if feature toggles should be available
    /// Available in DEBUG builds and TestFlight builds
    var isFeatureToggleAvailable: Bool {
        #if DEBUG
            return true
        #else
            return Bundle.main.isTestFlight
        #endif
    }

    private init() {}
}
