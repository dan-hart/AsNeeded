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
}
