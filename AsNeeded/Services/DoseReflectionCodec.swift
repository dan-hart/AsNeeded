import Foundation

enum DoseReflectionCodec {
	static let marker = "[[asn-dose-reflection-v1]]"

	private static let encoder = JSONEncoder()
	private static let decoder = JSONDecoder()

	static func reflection(from rawNote: String?) -> DoseReflection? {
		guard let rawNote, !rawNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
			return nil
		}

		guard rawNote.hasPrefix(marker) else {
			return DoseReflection(note: rawNote).sanitized()
		}

		let payload = String(rawNote.dropFirst(marker.count))
		guard let data = payload.data(using: .utf8),
		      let reflection = try? decoder.decode(DoseReflection.self, from: data)
		else {
			return DoseReflection(note: rawNote).sanitized()
		}

		let sanitized = reflection.sanitized()
		return sanitized.isEmpty ? nil : sanitized
	}

	static func displayNote(from rawNote: String?) -> String? {
		reflection(from: rawNote)?.note
	}

	static func encode(_ reflection: DoseReflection?) throws -> String? {
		guard let sanitized = reflection?.sanitized(), !sanitized.isEmpty else {
			return nil
		}

		if !sanitized.hasStructuredFields {
			return sanitized.note
		}

		let data = try encoder.encode(sanitized)
		guard let payload = String(data: data, encoding: .utf8) else {
			return nil
		}

		return marker + payload
	}

	static func updatingNote(in rawNote: String?, with newNote: String?) throws -> String? {
		var reflection = reflection(from: rawNote) ?? DoseReflection()
		reflection.note = newNote
		return try encode(reflection)
	}
}
