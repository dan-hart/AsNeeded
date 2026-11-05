import Foundation

/// Existing persisted and WatchConnectivity identifiers shared across targets.
/// Changing these values requires explicit storage or wire compatibility planning.
enum SharedPlatformContracts {
	enum Storage {
		static let appGroupIdentifier = "group.com.codedbydan.AsNeeded"
		static let medicationsDBName = "medications"
		static let eventsDBName = "events"
		static let databaseExtension = ".sqlite3"
	}

	enum Preferences {
		static let medicationSafetyProfiles = "medicationSafetyProfiles"
	}

	enum WatchMessage {
		static let getMedications = "getMedications"
		static let logDose = "logDose"
		static let updateQuantity = "updateQuantity"
		static let medications = "medications"
		static let doseLogged = "doseLogged"
		static let quantityUpdated = "quantityUpdated"
		static let saveFailed = "saveFailed"
		static let saved = "saved"
		static let received = "received"
		static let id = "id"
		static let displayName = "displayName"
		static let quantity = "quantity"
		static let prescribedDoseAmount = "prescribedDoseAmount"
		static let prescribedUnit = "prescribedUnit"
		static let canTakeNow = "canTakeNow"
		static let nextDoseDate = "nextDoseDate"
		static let lowStock = "lowStock"
		static let refillSoon = "refillSoon"
		static let statusMessage = "statusMessage"
		static let statusMessageKey = "statusMessageKey"
		static let medicationId = "medicationId"
		static let doseAmount = "doseAmount"
		static let doseUnit = "doseUnit"
		static let quantityConsumed = "quantityConsumed"
		static let eventID = "eventID"
		static let date = "date"
	}
}
