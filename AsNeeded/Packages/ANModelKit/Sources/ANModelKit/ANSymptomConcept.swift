// Create a new file for the ANSymptomConcept model.
import Foundation

public struct ANSymptomConcept: Identifiable, Codable, Equatable, Hashable {
    public let id: UUID
    public var name: String
    public var description: String?
    public var severityScale: Int?
    public var history: [Date]
    
    public init(id: UUID = UUID(), name: String, description: String? = nil, severityScale: Int? = nil, history: [Date] = []) {
        self.id = id
        self.name = name
        self.description = description
        self.severityScale = severityScale
        self.history = history
    }
    
    public var mostRecentLogged: Date? {
        history.sorted(by: >).first
    }
}
