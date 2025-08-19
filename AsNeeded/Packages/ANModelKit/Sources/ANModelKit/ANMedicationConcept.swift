import Foundation

/// Represents a medication definition with a clinical name and optional user nickname.
public struct ANMedicationConcept: Identifiable, Codable, Equatable, Hashable, Sendable {
    /// Unique identifier for this medication concept (Boutique best practice)
    public let id: UUID
    /// The official/clinical name of the medication
    public var clinicalName: String
    /// An optional user-supplied nickname for the medication (e.g. "Rescue Inhaler")
    public var nickname: String?
    /// The current quantity of the medication (e.g., number of pills, mL, etc.)
    public var quantity: Double?
    /// The date of the last refill
    public var lastRefillDate: Date?
    /// The date of the next expected refill
    public var nextRefillDate: Date?

    /// Initialize a new medication concept
    public init(id: UUID = UUID(), clinicalName: String, nickname: String? = nil, quantity: Double? = nil, lastRefillDate: Date? = nil, nextRefillDate: Date? = nil) {
        self.id = id
        self.clinicalName = clinicalName
        self.nickname = nickname
        self.quantity = quantity
        self.lastRefillDate = lastRefillDate
        self.nextRefillDate = nextRefillDate
    }
}
