// Dose information for a medication event
import Foundation

/// Represents a dose (amount and unit) for a medication.
public struct ANDoseConcept: Identifiable, Codable, Equatable, Hashable, Sendable {
	/// Unique identifier for this dose (Boutique best practice)
	public let id: UUID
	/// The amount for this dose (e.g. 5, or 1)
	public var amount: Double
	/// The unit for this dose (e.g. .milligram, .tablet, .puff)
	public var unit: ANUnitConcept

	/// Initialize a new dose concept
	/// - Parameters:
	///   - id: Unique identifier for this dose (optional, default is UUID())
	///   - amount: The numeric amount for the dose (e.g. 5, or 1)
	///   - unit: The unit for the dose (must be an ANUnitConcept value)
	public init(id: UUID = UUID(), amount: Double, unit: ANUnitConcept) {
		self.id = id
		self.amount = amount
		self.unit = unit
	}
}
