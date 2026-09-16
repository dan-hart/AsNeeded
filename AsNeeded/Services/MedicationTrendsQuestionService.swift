import ANModelKit
import Foundation

enum TrendsQuestionAvailability: Equatable {
	case unavailable
	case disabled
	case available
}

/// Why on-device questions are unavailable, when the device could otherwise support them.
enum TrendsQuestionUnavailableReason: Equatable, Sendable {
	/// The hardware or OS cannot run the on-device model. Nothing the user can change.
	case deviceNotEligible
	/// The device is eligible but Apple Intelligence is turned off in Settings.
	case appleIntelligenceNotEnabled
	/// Apple Intelligence is on but the model is still downloading or preparing.
	case modelNotReady

	var userGuidance: String {
		switch self {
		case .deviceNotEligible:
			return String(localized: "Private questions need a device that supports Apple Intelligence.")
		case .appleIntelligenceNotEnabled:
			return String(localized: "Turn on Apple Intelligence in iOS Settings to ask private questions about your trends.")
		case .modelNotReady:
			return String(localized: "Apple Intelligence is still getting ready on this device. Check back in a little while.")
		}
	}
}

/// Why the on-device model could not produce an answer, in terms the user can act on.
enum TrendsQuestionGenerationFailure: Equatable, Sendable {
	/// The prompt, including the history summary, is larger than the model can read at once.
	case tooMuchData
	/// The model assets are missing or still downloading.
	case modelNotReady
	/// The model declined the question, for example because of its safety guardrails.
	case declined
	/// The model does not support the current language or locale.
	case unsupportedLanguage
	/// The system is rate limiting or already running another request.
	case busy
	/// The model returned something that could not be read as an answer.
	case unexpectedResponse
	/// Any other failure from the model.
	case unknown

	var userMessage: String {
		switch self {
		case .tooMuchData:
			return String(localized: "There is more history than the on-device model can read at once. Try a shorter window.")
		case .modelNotReady:
			return String(localized: "Apple Intelligence is still getting ready on this device. Check back in a little while.")
		case .declined:
			return String(localized: "The on-device model declined to answer this question. Try rephrasing it.")
		case .unsupportedLanguage:
			return String(localized: "The on-device model does not support this language yet.")
		case .busy:
			return String(localized: "The on-device model is busy. Try again in a moment.")
		case .unexpectedResponse:
			return String(localized: "The on-device model returned something unexpected. Try asking again.")
		case .unknown:
			return String(localized: "The on-device model could not answer right now. Try again in a moment.")
		}
	}
}

enum TrendsQuestionServiceError: LocalizedError, Equatable {
	case unavailable
	case disabled
	/// The model was available but failed while answering. The payload says why in user terms.
	case generationFailed(TrendsQuestionGenerationFailure)

	var errorDescription: String? {
		switch self {
		case .unavailable:
			return "On-device questions are unavailable on this device."
		case .disabled:
			return "On-device questions are turned off in settings."
		case let .generationFailed(failure):
			return failure.userMessage
		}
	}
}

protocol TrendsQuestionGenerating: Sendable {
	func answer(prompt: String) async throws -> TrendsQuestionAnswer

	/// Streams progressively more complete answers while the model works, ending with the final answer.
	/// Generators that cannot stream fall back to yielding the complete answer once.
	func streamAnswer(prompt: String) -> AsyncThrowingStream<TrendsQuestionAnswer, Error>
}

extension TrendsQuestionGenerating {
	func streamAnswer(prompt: String) -> AsyncThrowingStream<TrendsQuestionAnswer, Error> {
		AsyncThrowingStream { continuation in
			let task = Task {
				do {
					let answer = try await self.answer(prompt: prompt)
					continuation.yield(answer)
					continuation.finish()
				} catch {
					continuation.finish(throwing: error)
				}
			}
			continuation.onTermination = { _ in task.cancel() }
		}
	}
}

struct MedicationTrendsQuestionService: Sendable {
	private let isEnabledProvider: @Sendable () -> Bool
	private let isSupportedProvider: @Sendable () -> Bool
	private let unavailableReasonProvider: @Sendable () -> TrendsQuestionUnavailableReason?
	private let generator: any TrendsQuestionGenerating

	init(
		isEnabledProvider: @escaping @Sendable () -> Bool = {
			UserDefaults.standard.bool(forKey: UserDefaultsKeys.trendsQuestionsEnabled)
		},
		isSupportedProvider: @escaping @Sendable () -> Bool = {
			MedicationTrendsQuestionSupport.isSupportedOnDevice
		},
		unavailableReasonProvider: @escaping @Sendable () -> TrendsQuestionUnavailableReason? = {
			MedicationTrendsQuestionSupport.unavailableReason
		},
		generator: (any TrendsQuestionGenerating)? = nil
	) {
		self.isEnabledProvider = isEnabledProvider
		self.isSupportedProvider = isSupportedProvider
		self.unavailableReasonProvider = unavailableReasonProvider
		self.generator = generator ?? OnDeviceTrendsQuestionGenerator()
	}

	/// The reason questions are unavailable, or nil when they are supported on this device.
	var unavailableReason: TrendsQuestionUnavailableReason? {
		guard !isSupportedProvider() else {
			return nil
		}
		return unavailableReasonProvider() ?? .deviceNotEligible
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

	/// Streams partial answers as the model generates them. The last element is the complete answer.
	func streamAnswer(question: String, context: TrendsQuestionContext) -> AsyncThrowingStream<TrendsQuestionAnswer, Error> {
		switch availability {
		case .unavailable:
			return AsyncThrowingStream { $0.finish(throwing: TrendsQuestionServiceError.unavailable) }
		case .disabled:
			return AsyncThrowingStream { $0.finish(throwing: TrendsQuestionServiceError.disabled) }
		case .available:
			return generator.streamAnswer(prompt: buildPrompt(question: question, context: context))
		}
	}
}
