import Foundation

struct WatchMedication: Identifiable, Codable {
    let id: UUID
    let displayName: String
    let quantity: Double
    let prescribedDoseAmount: Double?
    let prescribedUnit: String?

    init(id: UUID, displayName: String, quantity: Double, prescribedDoseAmount: Double? = nil, prescribedUnit: String? = nil) {
        self.id = id
        self.displayName = displayName
        self.quantity = quantity
        self.prescribedDoseAmount = prescribedDoseAmount
        self.prescribedUnit = prescribedUnit
    }

    init(from dict: [String: Any]) {
        id = UUID(uuidString: dict["id"] as? String ?? "") ?? UUID()
        displayName = dict["displayName"] as? String ?? "Unknown"
        quantity = dict["quantity"] as? Double ?? 0.0
        prescribedDoseAmount = dict["prescribedDoseAmount"] as? Double
        prescribedUnit = dict["prescribedUnit"] as? String
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
