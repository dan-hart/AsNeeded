import Foundation

#if canImport(FoundationModels)
	import FoundationModels
#endif

struct OnDeviceTrendsQuestionGenerator: TrendsQuestionGenerating {
	func answer(prompt: String) async throws -> TrendsQuestionAnswer {
		#if canImport(FoundationModels)
			if #available(iOS 26.0, *) {
				let session = LanguageModelSession(
					model: .default,
					instructions: """
					You analyze only the medication history data supplied in the prompt.
					Stay descriptive and gently interpret patterns, but never give medical advice or instructions.
					Call out uncertainty when the data is incomplete.
					"""
				)

				let response = try await session.respond(
					to: prompt,
					generating: GeneratedTrendsQuestionAnswer.self
				)

				return TrendsQuestionAnswer(
					answer: response.content.answer.trimmingCharacters(in: .whitespacesAndNewlines),
					highlights: response.content.highlights
						.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
						.filter { !$0.isEmpty },
					limitations: response.content.limitations
						.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
						.filter { !$0.isEmpty }
				)
			}
		#endif

		throw TrendsQuestionServiceError.unavailable
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
