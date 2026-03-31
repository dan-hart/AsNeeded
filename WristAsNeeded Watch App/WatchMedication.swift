import Foundation

struct WatchMedication: Identifiable, Codable {
    let id: UUID
    let displayName: String
    let quantity: Double
    let prescribedDoseAmount: Double?
    let prescribedUnit: String?
    let canTakeNow: Bool
    let nextDoseDate: Date?
    let lowStock: Bool
    let refillSoon: Bool
    let statusMessage: String?

    init(
        id: UUID,
        displayName: String,
        quantity: Double,
        prescribedDoseAmount: Double? = nil,
        prescribedUnit: String? = nil,
        canTakeNow: Bool = true,
        nextDoseDate: Date? = nil,
        lowStock: Bool = false,
        refillSoon: Bool = false,
        statusMessage: String? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.quantity = quantity
        self.prescribedDoseAmount = prescribedDoseAmount
        self.prescribedUnit = prescribedUnit
        self.canTakeNow = canTakeNow
        self.nextDoseDate = nextDoseDate
        self.lowStock = lowStock
        self.refillSoon = refillSoon
        self.statusMessage = statusMessage
    }

    init(from dict: [String: Any]) {
        id = UUID(uuidString: dict["id"] as? String ?? "") ?? UUID()
        displayName = dict["displayName"] as? String ?? "Unknown"
        quantity = dict["quantity"] as? Double ?? 0.0
        prescribedDoseAmount = dict["prescribedDoseAmount"] as? Double
        prescribedUnit = dict["prescribedUnit"] as? String
        canTakeNow = dict["canTakeNow"] as? Bool ?? true
        nextDoseDate = dict["nextDoseDate"] as? Date
        lowStock = dict["lowStock"] as? Bool ?? false
        refillSoon = dict["refillSoon"] as? Bool ?? false
        statusMessage = dict["statusMessage"] as? String
    }
}

extension WatchMedication: Equatable {
    static func == (lhs: WatchMedication, rhs: WatchMedication) -> Bool {
        lhs.id == rhs.id
    }
}

extension WatchMedication: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
