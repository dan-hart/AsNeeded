import Foundation

/// Represents a medication definition with a clinical name and optional user nickname.
public struct ANMedicationConcept: Identifiable, Codable, Equatable, Hashable {
    /// Unique identifier for this medication concept (Boutique best practice)
    public let id: UUID
    /// The official/clinical name of the medication
    public var clinicalName: String
    /// An optional user-supplied nickname for the medication (e.g. "Rescue Inhaler")
    public var nickname: String?

    /// Initialize a new medication concept
    public init(id: UUID = UUID(), clinicalName: String, nickname: String? = nil) {
        self.id = id
        self.clinicalName = clinicalName
        self.nickname = nickname
    }
}
