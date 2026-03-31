import ANModelKit
import Foundation

enum TrendsQuestionAvailability: Equatable {
	case unavailable
	case disabled
	case available
}

enum TrendsQuestionServiceError: LocalizedError {
	case unavailable
	case disabled

	var errorDescription: String? {
		switch self {
		case .unavailable:
			return "On-device questions are unavailable on this device."
		case .disabled:
			return "On-device questions are turned off in settings."
		}
	}
}

protocol TrendsQuestionGenerating: Sendable {
	func answer(prompt: String) async throws -> TrendsQuestionAnswer
}

struct MedicationTrendsQuestionService: Sendable {
	private let isEnabledProvider: @Sendable () -> Bool
	private let isSupportedProvider: @Sendable () -> Bool
	private let generator: any TrendsQuestionGenerating

	init(
		isEnabledProvider: @escaping @Sendable () -> Bool = {
			UserDefaults.standard.bool(forKey: UserDefaultsKeys.trendsQuestionsEnabled)
		},
		isSupportedProvider: @escaping @Sendable () -> Bool = {
			MedicationTrendsQuestionSupport.isSupportedOnDevice
		},
		generator: (any TrendsQuestionGenerating)? = nil
	) {
		self.isEnabledProvider = isEnabledProvider
		self.isSupportedProvider = isSupportedProvider
		self.generator = generator ?? OnDeviceTrendsQuestionGenerator()
	}

	var availability: TrendsQuestionAvailability {
		guard isSupportedProvider() else {
			return .unavailable
		}

		guard isEnabledProvider() else {
			return .disabled
		}

		return .available
	}

	func examplePrompts(for medication: ANMedicationConcept) -> [String] {
		let name = medication.displayName
		return [
			"When do I usually log \(name)?",
			"Has my \(name) use been picking up lately?",
			"How consistent have my \(name) logs been this month?",
			"What should I notice about my recent \(name) pattern?",
		]
	}

	func buildPrompt(question: String, context: TrendsQuestionContext) -> String {
		let totals = context.dailyTotals
			.map { "\($0.dayLabel): \($0.total.formattedAmount)" }
			.joined(separator: "\n")

		return """
		Use only the supplied data.
		Do not give medical advice.
		Do not recommend dose changes, treatment changes, or what the user should do next.
		If the data is sparse or uncertain, say so clearly.
		Answer the question directly, then surface a few concise observations and any limitations.

		Medication: \(context.medicationName)
		Unit: \(context.unitName)
		Window: \(context.windowDays) days
		Quantity summary: \(context.quantitySummary)
		Refill summary: \(context.refillSummary)
		Pattern summary: \(context.patternSummary)
		Daily totals:
		\(totals)

		User question: \(question)
		"""
	}

	func answer(question: String, context: TrendsQuestionContext) async throws -> TrendsQuestionAnswer {
		switch availability {
		case .unavailable:
			throw TrendsQuestionServiceError.unavailable
		case .disabled:
			throw TrendsQuestionServiceError.disabled
		case .available:
			let prompt = buildPrompt(question: question, context: context)
			return try await generator.answer(prompt: prompt)
		}
	}
}
