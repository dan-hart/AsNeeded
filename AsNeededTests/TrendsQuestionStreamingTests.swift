import ANModelKit
import Foundation
import Testing
@testable import AsNeeded

/// Covers the streaming and phase behavior added for the private-questions UX.
@Suite("Trends Question Streaming Tests")
struct TrendsQuestionStreamingTests {
	private struct SingleShotGenerator: TrendsQuestionGenerating {
		let answer: TrendsQuestionAnswer
		func answer(prompt: String) async throws -> TrendsQuestionAnswer { answer }
	}

	/// Emits partials in order, pausing between them so a test can observe intermediate phases or cancel.
	private struct StreamingGenerator: TrendsQuestionGenerating {
		let partials: [TrendsQuestionAnswer]
		let delayNanoseconds: UInt64

		func answer(prompt: String) async throws -> TrendsQuestionAnswer {
			guard let last = partials.last else { throw TrendsQuestionServiceError.unavailable }
			return last
		}

		func streamAnswer(prompt: String) -> AsyncThrowingStream<TrendsQuestionAnswer, Error> {
			AsyncThrowingStream { continuation in
				let task = Task {
					for partial in partials {
						try Task.checkCancellation()
						continuation.yield(partial)
						try await Task.sleep(nanoseconds: delayNanoseconds)
					}
					continuation.finish()
				}
				continuation.onTermination = { _ in task.cancel() }
			}
		}
	}

	private struct FailingGenerator: TrendsQuestionGenerating {
		struct Failure: LocalizedError {
			var errorDescription: String? { "The model stopped early." }
		}

		func answer(prompt: String) async throws -> TrendsQuestionAnswer { throw Failure() }
	}

	private static let sampleAnswer = TrendsQuestionAnswer(
		answer: "Most logs land in the evening.",
		highlights: ["Evenings dominate"],
		limitations: ["Only 14 days of data"]
	)

	private static func service(
		generator: any TrendsQuestionGenerating,
		enabled: Bool = true,
		supported: Bool = true,
		reason: TrendsQuestionUnavailableReason? = nil
	) -> MedicationTrendsQuestionService {
		MedicationTrendsQuestionService(
			isEnabledProvider: { enabled },
			isSupportedProvider: { supported },
			unavailableReasonProvider: { reason },
			generator: generator
		)
	}

	private static func context() -> TrendsQuestionContext {
		TrendsQuestionContext(
			medicationName: "Ibuprofen",
			unitName: "tablet",
			windowDays: 14,
			dailyTotals: [TrendsQuestionDailyTotal(dayLabel: "Jun 1", total: 1)],
			patternSummary: "Mostly evenings.",
			refillSummary: "No projection yet.",
			quantitySummary: "10 tablets left."
		)
	}

	@MainActor
	private static func makeViewModel(generator: any TrendsQuestionGenerating) async throws -> MedicationTrendsViewModel {
		let dataStore = DataStore(testIdentifier: "trends-question-streaming-\(UUID().uuidString)")
		let medication = ANMedicationConcept(
			id: UUID(),
			clinicalName: "Ibuprofen",
			quantity: 10,
			prescribedUnit: .tablet,
			prescribedDoseAmount: 1
		)
		try await dataStore.addMedication(medication)
		let event = ANEventConcept(
			eventType: .doseTaken,
			medication: medication,
			dose: ANDoseConcept(amount: 1, unit: .tablet),
			date: Date().addingTimeInterval(-3600),
			note: nil
		)
		try await dataStore.addEvent(event, shouldRecordForReview: false)
		return MedicationTrendsViewModel(
			dataStore: dataStore,
			selectedMedicationID: medication.id,
			questionService: service(generator: generator)
		)
	}

	// MARK: - Service

	@Test("Generators without streaming support fall back to a single complete answer")
	func defaultStreamYieldsOnce() async throws {
		let service = Self.service(generator: SingleShotGenerator(answer: Self.sampleAnswer))
		var received: [TrendsQuestionAnswer] = []
		for try await partial in service.streamAnswer(question: "When?", context: Self.context()) {
			received.append(partial)
		}
		#expect(received == [Self.sampleAnswer])
	}

	@Test("Streaming respects availability before touching the generator")
	func streamRespectsAvailability() async {
		let disabled = Self.service(generator: SingleShotGenerator(answer: Self.sampleAnswer), enabled: false)
		var thrown: Error?
		do {
			for try await _ in disabled.streamAnswer(question: "When?", context: Self.context()) {}
		} catch {
			thrown = error
		}
		#expect(thrown?.localizedDescription == TrendsQuestionServiceError.disabled.localizedDescription)
	}

	@Test("Unavailable reason is surfaced only when the device does not support questions")
	func unavailableReasonMapping() {
		let unsupported = Self.service(generator: SingleShotGenerator(answer: Self.sampleAnswer), supported: false, reason: .appleIntelligenceNotEnabled)
		#expect(unsupported.unavailableReason == .appleIntelligenceNotEnabled)

		let unknownReason = Self.service(generator: SingleShotGenerator(answer: Self.sampleAnswer), supported: false, reason: nil)
		#expect(unknownReason.unavailableReason == .deviceNotEligible)

		let supported = Self.service(generator: SingleShotGenerator(answer: Self.sampleAnswer), supported: true, reason: .modelNotReady)
		#expect(supported.unavailableReason == nil)
	}

	// MARK: - View model phases

	@Test("Asking moves through preparing, generating, and answered with the final partial")
	@MainActor
	func phasesProgressToAnswered() async throws {
		let partials = [
			TrendsQuestionAnswer(answer: "Most", highlights: [], limitations: []),
			TrendsQuestionAnswer(answer: "Most logs land", highlights: [], limitations: []),
			Self.sampleAnswer,
		]
		let viewModel = try await Self.makeViewModel(generator: StreamingGenerator(partials: partials, delayNanoseconds: 5_000_000))
		#expect(viewModel.questionPhase == .idle)

		await viewModel.ask(question: "  When do I usually log this?  ", windowDays: 14)

		#expect(viewModel.questionPhase == .answered(Self.sampleAnswer))
		#expect(viewModel.latestQuestionAnswer == Self.sampleAnswer)
		#expect(viewModel.askedQuestion == "When do I usually log this?")
		#expect(viewModel.isAnsweringQuestion == false)
		#expect(viewModel.questionErrorMessage == nil)
	}

	@Test("A generator error lands in the failed phase with its message")
	@MainActor
	func failurePhaseCarriesMessage() async throws {
		let viewModel = try await Self.makeViewModel(generator: FailingGenerator())
		await viewModel.ask(question: "Anything?", windowDays: 14)

		#expect(viewModel.questionPhase == .failed("The model stopped early."))
		#expect(viewModel.questionErrorMessage == "The model stopped early.")
		#expect(viewModel.latestQuestionAnswer == nil)
		#expect(viewModel.isAnsweringQuestion == false)
	}

	@Test("Cancelling a question in flight returns to idle without an answer or error")
	@MainActor
	func cancelReturnsToIdle() async throws {
		let partials = [
			TrendsQuestionAnswer(answer: "Most", highlights: [], limitations: []),
			Self.sampleAnswer,
		]
		let viewModel = try await Self.makeViewModel(generator: StreamingGenerator(partials: partials, delayNanoseconds: 300_000_000))

		let asking = Task { await viewModel.ask(question: "When?", windowDays: 14) }
		try await Task.sleep(nanoseconds: 60_000_000)
		#expect(viewModel.questionPhase.isWorking)
		viewModel.cancelQuestion()
		await asking.value

		#expect(viewModel.questionPhase == .idle)
		#expect(viewModel.isAnsweringQuestion == false)
		#expect(viewModel.latestQuestionAnswer == nil)
		#expect(viewModel.questionErrorMessage == nil)
	}

	@Test("A second question supersedes the first without the first resetting the phase")
	@MainActor
	func secondQuestionSupersedesFirst() async throws {
		let partials = [
			TrendsQuestionAnswer(answer: "Most", highlights: [], limitations: []),
			Self.sampleAnswer,
		]
		let viewModel = try await Self.makeViewModel(generator: StreamingGenerator(partials: partials, delayNanoseconds: 150_000_000))

		let first = Task { await viewModel.ask(question: "First?", windowDays: 14) }
		try await Task.sleep(nanoseconds: 40_000_000)
		let second = Task { await viewModel.ask(question: "Second?", windowDays: 14) }
		await first.value
		// The cancelled first task must not have dropped the phase to idle while the second is working.
		#expect(viewModel.questionPhase != .idle)
		#expect(viewModel.askedQuestion == "Second?")
		await second.value

		#expect(viewModel.questionPhase == .answered(Self.sampleAnswer))
		#expect(viewModel.askedQuestion == "Second?")
		#expect(viewModel.isAnsweringQuestion == false)
	}

	@Test("Reset clears the answer, error, and echoed question")
	@MainActor
	func resetClearsState() async throws {
		let viewModel = try await Self.makeViewModel(generator: SingleShotGenerator(answer: Self.sampleAnswer))
		await viewModel.ask(question: "When?", windowDays: 14)
		#expect(viewModel.latestQuestionAnswer == Self.sampleAnswer)

		viewModel.resetQuestion()

		#expect(viewModel.questionPhase == .idle)
		#expect(viewModel.latestQuestionAnswer == nil)
		#expect(viewModel.askedQuestion == nil)
		#expect(viewModel.questionErrorMessage == nil)
	}
}
