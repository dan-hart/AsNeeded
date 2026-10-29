import Foundation

/// Widget links carry stable identifiers only. Every destination opens UI and never records a dose.
enum WidgetNavigationRoute: Equatable, Sendable {
	case medications
	case medication(UUID)
	case logDose(UUID?)
	case history(UUID)
	case trends(UUID, days: Int)

	var url: URL? {
		var components = URLComponents()
		components.scheme = "asneeded"
		switch self {
		case .medications: components.host = "medications"
		case let .medication(id): components.host = "medication"; components.path = "/\(id.uuidString)"
		case let .logDose(id): components.host = "log"; components.path = id.map { "/\($0.uuidString)" } ?? ""
		case let .history(id): components.host = "history"; components.path = "/\(id.uuidString)"
		case let .trends(id, days):
			guard days == 7 else { return nil }
			components.host = "trends"
			components.path = "/\(id.uuidString)"
			components.queryItems = [URLQueryItem(name: "days", value: String(days))]
		}
		return components.url
	}

	init?(url: URL) {
		guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
			components.scheme?.lowercased() == "asneeded", components.user == nil, components.password == nil,
			components.port == nil, components.fragment == nil else { return nil }
		let parts = components.path.split(separator: "/", omittingEmptySubsequences: true)
		let query = components.queryItems ?? []
		if components.host == "medications", parts.isEmpty, query.isEmpty { self = .medications; return }
		if components.host == "log", parts.isEmpty, query.isEmpty { self = .logDose(nil); return }
		guard parts.count == 1, components.path == "/" + String(parts[0]), let id = UUID(uuidString: String(parts[0])) else { return nil }
		switch components.host {
		case "medication" where query.isEmpty: self = .medication(id)
		case "log" where query.isEmpty: self = .logDose(id)
		case "history" where query.isEmpty: self = .history(id)
		case "trends" where query.count == 1 && query.first?.name == "days" && query.first?.value == "7":
			self = .trends(id, days: 7)
		default: return nil
		}
	}

	var medicationID: UUID? {
		switch self {
		case .medications: nil
		case let .medication(id), let .history(id), let .trends(id, _): id
		case let .logDose(id): id
		}
	}
}
