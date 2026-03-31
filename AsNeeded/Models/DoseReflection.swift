import Foundation

struct DoseReflection: Codable, Equatable, Sendable {
	var reason: String?
	var symptomSeverityBefore: Int?
	var symptomSeverityAfter: Int?
	var effectiveness: Int?
	var sideEffects: [String]
	var note: String?

	init(
		reason: String? = nil,
		symptomSeverityBefore: Int? = nil,
		symptomSeverityAfter: Int? = nil,
		effectiveness: Int? = nil,
		sideEffects: [String] = [],
		note: String? = nil
	) {
		self.reason = reason
		self.symptomSeverityBefore = symptomSeverityBefore
		self.symptomSeverityAfter = symptomSeverityAfter
		self.effectiveness = effectiveness
		self.sideEffects = sideEffects
		self.note = note
	}

	var isEmpty: Bool {
		sanitized().reason == nil &&
			sanitized().symptomSeverityBefore == nil &&
			sanitized().symptomSeverityAfter == nil &&
			sanitized().effectiveness == nil &&
			sanitized().sideEffects.isEmpty &&
			sanitized().note == nil
	}

	var hasStructuredFields: Bool {
		sanitized().reason != nil ||
			sanitized().symptomSeverityBefore != nil ||
			sanitized().symptomSeverityAfter != nil ||
			sanitized().effectiveness != nil ||
			!sanitized().sideEffects.isEmpty
	}

	func sanitized() -> DoseReflection {
		DoseReflection(
			reason: reason?.trimmedNilIfEmpty,
			symptomSeverityBefore: symptomSeverityBefore,
			symptomSeverityAfter: symptomSeverityAfter,
			effectiveness: effectiveness,
			sideEffects: sideEffects
				.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
				.filter { !$0.isEmpty },
			note: note?.trimmedNilIfEmpty
		)
	}
}

private extension String {
	var trimmedNilIfEmpty: String? {
		let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
		return trimmed.isEmpty ? nil : trimmed
	}
}
