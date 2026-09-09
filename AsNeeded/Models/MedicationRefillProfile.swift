import Foundation

struct MedicationRefillProfile: Codable, Equatable, Sendable {
	static let empty = MedicationRefillProfile()

	var lowStockThreshold: Double?

	var isEmpty: Bool {
		lowStockThreshold == nil
	}
}
