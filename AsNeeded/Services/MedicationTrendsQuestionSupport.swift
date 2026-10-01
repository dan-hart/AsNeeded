import Foundation

#if canImport(FoundationModels)
	import FoundationModels
#endif

enum MedicationTrendsQuestionSupport {
	static var isSupportedOnDevice: Bool {
		#if canImport(FoundationModels)
			if #available(iOS 26.0, *) {
				if case .available = SystemLanguageModel.default.availability {
					return true
				}
			}
		#endif

		return false
	}

	/// The system's reason for the on-device model being unavailable, when it is.
	static var unavailableReason: TrendsQuestionUnavailableReason? {
		#if canImport(FoundationModels)
			if #available(iOS 26.0, *) {
				switch SystemLanguageModel.default.availability {
				case .available:
					return nil
				case let .unavailable(reason):
					switch reason {
					case .deviceNotEligible:
						return .deviceNotEligible
					case .appleIntelligenceNotEnabled:
						return .appleIntelligenceNotEnabled
					case .modelNotReady:
						return .modelNotReady
					@unknown default:
						return .deviceNotEligible
					}
				}
			}
		#endif

		return .deviceNotEligible
	}
}
