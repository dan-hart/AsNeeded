import Foundation

struct MedicationSafetyProfile: Codable, Equatable, Sendable {
	static let defaultDuplicateDoseWindowMinutes = 30
	static let defaultRefillLeadDays = 5
	static let empty = MedicationSafetyProfile()

	var minimumHoursBetweenDoses: Double?
	var cautionHoursBetweenDoses: Double?
	var maxDailyAmount: Double?
	var duplicateDoseWindowMinutes: Int
	var lowStockThreshold: Double?
	var refillLeadDays: Int

	init(
		minimumHoursBetweenDoses: Double? = nil,
		cautionHoursBetweenDoses: Double? = nil,
		maxDailyAmount: Double? = nil,
		duplicateDoseWindowMinutes: Int = MedicationSafetyProfile.defaultDuplicateDoseWindowMinutes,
		lowStockThreshold: Double? = nil,
		refillLeadDays: Int = MedicationSafetyProfile.defaultRefillLeadDays
	) {
		self.minimumHoursBetweenDoses = minimumHoursBetweenDoses
		self.cautionHoursBetweenDoses = cautionHoursBetweenDoses
		self.maxDailyAmount = maxDailyAmount
		self.duplicateDoseWindowMinutes = duplicateDoseWindowMinutes
		self.lowStockThreshold = lowStockThreshold
		self.refillLeadDays = refillLeadDays
	}

	var isEmpty: Bool {
		minimumHoursBetweenDoses == nil &&
			cautionHoursBetweenDoses == nil &&
			maxDailyAmount == nil &&
			lowStockThreshold == nil &&
			duplicateDoseWindowMinutes == Self.defaultDuplicateDoseWindowMinutes &&
			refillLeadDays == Self.defaultRefillLeadDays
	}

	var normalizedCautionHoursBetweenDoses: Double? {
		switch (minimumHoursBetweenDoses, cautionHoursBetweenDoses) {
		case let (.some(minimum), .some(caution)):
			return max(minimum, caution)
		case let (_, .some(caution)):
			return caution
		case let (.some(minimum), .none):
			return minimum
		case (.none, .none):
			return nil
		}
	}
}
