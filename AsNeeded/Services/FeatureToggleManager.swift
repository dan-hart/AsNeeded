import SwiftUI

/// Manages feature toggles for experimental or debug features
@MainActor
final class FeatureToggleManager: ObservableObject {
	static let shared = FeatureToggleManager()

	// Feature Toggle for Quick Phrases - OFF by default
	@AppStorage(UserDefaultsKeys.featureToggleQuickPhrases) public var quickPhrasesEnabled: Bool = false

	private init() {}
}