import Foundation

#if canImport(FoundationModels)
	import FoundationModels
#endif

struct OnDeviceTrendsQuestionGenerator: TrendsQuestionGenerating {
	private static let instructions = """
	You analyze only the medication history data supplied in the prompt.
	Stay descriptive and gently interpret patterns, but never give medical advice or instructions.
	Call out uncertainty when the data is incomplete.
	"""

	func answer(prompt: String) async throws -> TrendsQuestionAnswer {
		#if canImport(FoundationModels)
			if #available(iOS 26.0, *) {
				let session = LanguageModelSession(model: .default, instructions: Self.instructions)
				let response = try await session.respond(
					to: prompt,
					generating: GeneratedTrendsQuestionAnswer.self
				)
				return Self.cleaned(
					answer: response.content.answer,
					highlights: response.content.highlights,
					limitations: response.content.limitations
				)
			}
		#endif

		throw TrendsQuestionServiceError.unavailable
	}

	/// Streams partial answers as the on-device model fills in the structured response.
	func streamAnswer(prompt: String) -> AsyncThrowingStream<TrendsQuestionAnswer, Error> {
		#if canImport(FoundationModels)
			if #available(iOS 26.0, *) {
				return AsyncThrowingStream { continuation in
					let task = Task {
						do {
							let session = LanguageModelSession(model: .default, instructions: Self.instructions)
							let stream = session.streamResponse(
								to: prompt,
								generating: GeneratedTrendsQuestionAnswer.self
							)
							var latest = TrendsQuestionAnswer(answer: "", highlights: [], limitations: [])
							for try await snapshot in stream {
								try Task.checkCancellation()
								let partial = snapshot.content
								latest = Self.cleaned(
									answer: partial.answer ?? "",
									highlights: partial.highlights ?? [],
									limitations: partial.limitations ?? []
								)
								continuation.yield(latest)
							}
							continuation.finish()
						} catch {
							continuation.finish(throwing: error)
						}
					}
					continuation.onTermination = { _ in task.cancel() }
				}
			}
		#endif

		return AsyncThrowingStream { $0.finish(throwing: TrendsQuestionServiceError.unavailable) }
	}

	private static func cleaned(answer: String, highlights: [String], limitations: [String]) -> TrendsQuestionAnswer {
		TrendsQuestionAnswer(
			answer: answer.trimmingCharacters(in: .whitespacesAndNewlines),
			highlights: highlights
				.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
				.filter { !$0.isEmpty },
			limitations: limitations
				.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
				.filter { !$0.isEmpty }
		)
	}
}

#if canImport(FoundationModels)
	@available(iOS 26.0, *)
	@Generable(description: "A concise answer based only on the supplied medication-tracking data.")
	private struct GeneratedTrendsQuestionAnswer {
		@Guide(description: "Answer directly using only the supplied data. No advice or recommendations.")
		var answer: String

		@Guide(description: "Two or three concise observations about notable patterns in the supplied data.")
		var highlights: [String]

		@Guide(description: "Short notes about sparse data, missing information, or uncertainty.")
		var limitations: [String]
	}
#endif
