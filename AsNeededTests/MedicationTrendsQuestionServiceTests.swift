import ANModelKit
@testable import AsNeeded
import Foundation
import Testing

@Suite("MedicationTrendsQuestionService Tests", .tags(.unit, .trends))
struct MedicationTrendsQuestionServiceTests {
	private struct MockGenerator: TrendsQuestionGenerating {
		let answerResult: TrendsQuestionAnswer

		func answer(prompt: String) async throws -> TrendsQuestionAnswer {
			answerResult
		}
	}

	private struct ThrowingGenerator: TrendsQuestionGenerating {
		let error: any Error

		func answer(prompt: String) async throws -> TrendsQuestionAnswer {
			throw error
		}
	}

	private func medication() -> ANMedicationConcept {
		ANMedicationConcept(
			clinicalName: "Ibuprofen",
			nickname: nil,
			quantity: 18,
			initialQuantity: 30,
			lastRefillDate: Date().addingTimeInterval(-12 * 86_400),
			nextRefillDate: Date().addingTimeInterval(6 * 86_400),
			prescribedUnit: .tablet,
			prescribedDoseAmount: 2
		)
	}

	private func context() -> TrendsQuestionContext {
		TrendsQuestionContext(
			medicationName: "Ibuprofen",
			unitName: "tablet",
			windowDays: 14,
			dailyTotals: [
				TrendsQuestionDailyTotal(dayLabel: "Mar 17", total: 2),
				TrendsQuestionDailyTotal(dayLabel: "Mar 18", total: 0),
				TrendsQuestionDailyTotal(dayLabel: "Mar 19", total: 4),
			],
			patternSummary: "Use clusters around late evenings.",
			refillSummary: "About 6 days remaining at the recent pace.",
			quantitySummary: "18 tablets left."
		)
	}

	@Test("Feature is unavailable when device support is missing")
	func featureUnavailableWithoutDeviceSupport() {
		let service = MedicationTrendsQuestionService(
			isEnabledProvider: { true },
			isSupportedProvider: { false },
			generator: MockGenerator(
				answerResult: TrendsQuestionAnswer(
					answer: "Unused",
					highlights: [],
					limitations: []
				)
			)
		)

		#expect(service.availability == .unavailable)
	}

	@Test("Feature is disabled when user preference is off")
	func featureDisabledWhenPreferenceOff() {
		let service = MedicationTrendsQuestionService(
			isEnabledProvider: { false },
			isSupportedProvider: { true },
			generator: MockGenerator(
				answerResult: TrendsQuestionAnswer(
					answer: "Unused",
					highlights: [],
					limitations: []
				)
			)
		)

		#expect(service.availability == .disabled)
	}

	@Test("Feature is available when device support and preference are both enabled")
	func featureAvailableWhenSupportedAndEnabled() {
		let service = MedicationTrendsQuestionService(
			isEnabledProvider: { true },
			isSupportedProvider: { true },
			generator: MockGenerator(
				answerResult: TrendsQuestionAnswer(
					answer: "Unused",
					highlights: [],
					limitations: []
				)
			)
		)

		#expect(service.availability == .available)
	}

	@Test("Example prompts are tailored to the selected medication")
	func examplePromptsTailoredToMedication() {
		let service = MedicationTrendsQuestionService(
			isEnabledProvider: { true },
			isSupportedProvider: { true },
			generator: MockGenerator(
				answerResult: TrendsQuestionAnswer(
					answer: "Unused",
					highlights: [],
					limitations: []
				)
			)
		)

		let prompts = service.examplePrompts(for: medication())

		#expect(prompts.count == 4)
		#expect(prompts.allSatisfy { $0.contains("Ibuprofen") })
	}

	@Test("Prompt builder includes hard constraints and local data summary")
	func promptBuilderIncludesConstraintsAndDataSummary() {
		let service = MedicationTrendsQuestionService(
			isEnabledProvider: { true },
			isSupportedProvider: { true },
			generator: MockGenerator(
				answerResult: TrendsQuestionAnswer(
					answer: "Unused",
					highlights: [],
					limitations: []
				)
			)
		)

		let prompt = service.buildPrompt(
			question: "Do I use it more on weekends?",
			context: context()
		)

		#expect(prompt.contains("Use only the supplied data"))
		#expect(prompt.contains("Do not give medical advice"))
		#expect(prompt.contains("Ibuprofen"))
		#expect(prompt.contains("Mar 19: 4"))
		#expect(prompt.contains("late evenings"))
	}

	@Test("Answer request forwards generated content when available")
	func answerRequestForwardsGeneratedContent() async throws {
		let expected = TrendsQuestionAnswer(
			answer: "Your recent logs are heavier on a few late-evening days.",
			highlights: ["Usage is clustered, not daily."],
			limitations: ["The sample is only fourteen days long."]
		)
		let service = MedicationTrendsQuestionService(
			isEnabledProvider: { true },
			isSupportedProvider: { true },
			generator: MockGenerator(answerResult: expected)
		)

		let answer = try await service.answer(
			question: "When do I use it most?",
			context: context()
		)

		#expect(answer == expected)
	}

	@Test("Answer request throws unavailable when device support is missing")
	func answerRequestThrowsUnavailableWhenUnsupported() async {
		let service = MedicationTrendsQuestionService(
			isEnabledProvider: { true },
			isSupportedProvider: { false },
			generator: ThrowingGenerator(error: TrendsQuestionServiceError.unavailable)
		)

		await #expect(throws: TrendsQuestionServiceError.unavailable) {
			try await service.answer(
				question: "When do I use it most?",
				context: context()
			)
		}
	}

	@Test("Disabled and unavailable error descriptions explain the setting state")
	func errorDescriptionsExplainState() {
		#expect(TrendsQuestionServiceError.unavailable.errorDescription == "On-device questions are unavailable on this device.")
		#expect(TrendsQuestionServiceError.disabled.errorDescription == "On-device questions are turned off in settings.")
	}
}
