// Dose information for a medication event
import Foundation

/// Represents a dose (amount and unit) for a medication.
public struct ANDoseConcept: Identifiable, Codable, Equatable, Hashable {
    /// Unique identifier for this dose (Boutique best practice)
    public let id: UUID
    /// The amount for this dose (e.g. 5, or 1)
    public var amount: Double
    /// The unit for this dose (e.g. "mg", "tablets", "puffs")
    public var unit: String

    /// Initialize a new dose concept
    public init(id: UUID = UUID(), amount: Double, unit: String) {
        self.id = id
        self.amount = amount
        self.unit = unit
    }
}
