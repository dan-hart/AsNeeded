@testable import AsNeeded
import Foundation
import Testing

struct SharedPlatformContractTests {
	@Test("Production storage aliases retain the existing container and filenames")
	func storageCompatibility() {
		#expect(StorageConstants.appGroupIdentifier == "group.com.codedbydan.AsNeeded")
		#expect(StorageConstants.medicationsDBName == "medications")
		#expect(StorageConstants.eventsDBName == "events")
		#expect(StorageConstants.databaseExtension == ".sqlite3")
		#expect(StorageConstants.medicationsDBPath == "medications.sqlite3")
		#expect(StorageConstants.eventsDBPath == "events.sqlite3")
		#expect(StorageConstants.currentStorageVersion == 2)
		#expect(UserDefaultsKeys.medicationSafetyProfiles == "medicationSafetyProfiles")
	}

	@Test("Watch wire keys retain their exact pre-centralization spelling")
	func watchKeyCompatibility() {
		#expect(SharedPlatformContracts.WatchMessage.getMedications == "getMedications")
		#expect(SharedPlatformContracts.WatchMessage.logDose == "logDose")
		#expect(SharedPlatformContracts.WatchMessage.updateQuantity == "updateQuantity")
		#expect(SharedPlatformContracts.WatchMessage.medications == "medications")
		#expect(SharedPlatformContracts.WatchMessage.doseLogged == "doseLogged")
		#expect(SharedPlatformContracts.WatchMessage.quantityUpdated == "quantityUpdated")
		#expect(SharedPlatformContracts.WatchMessage.saveFailed == "saveFailed")
		#expect(SharedPlatformContracts.WatchMessage.saved == "saved")
		#expect(SharedPlatformContracts.WatchMessage.received == "received")
		#expect(SharedPlatformContracts.WatchMessage.id == "id")
		#expect(SharedPlatformContracts.WatchMessage.displayName == "displayName")
		#expect(SharedPlatformContracts.WatchMessage.quantity == "quantity")
		#expect(SharedPlatformContracts.WatchMessage.prescribedDoseAmount == "prescribedDoseAmount")
		#expect(SharedPlatformContracts.WatchMessage.prescribedUnit == "prescribedUnit")
		#expect(SharedPlatformContracts.WatchMessage.canTakeNow == "canTakeNow")
		#expect(SharedPlatformContracts.WatchMessage.nextDoseDate == "nextDoseDate")
		#expect(SharedPlatformContracts.WatchMessage.lowStock == "lowStock")
		#expect(SharedPlatformContracts.WatchMessage.refillSoon == "refillSoon")
		#expect(SharedPlatformContracts.WatchMessage.statusMessage == "statusMessage")
		#expect(SharedPlatformContracts.WatchMessage.statusMessageKey == "statusMessageKey")
		#expect(SharedPlatformContracts.WatchMessage.medicationId == "medicationId")
		#expect(SharedPlatformContracts.WatchMessage.doseAmount == "doseAmount")
		#expect(SharedPlatformContracts.WatchMessage.doseUnit == "doseUnit")
		#expect(SharedPlatformContracts.WatchMessage.quantityConsumed == "quantityConsumed")
		#expect(SharedPlatformContracts.WatchMessage.eventID == "eventID")
		#expect(SharedPlatformContracts.WatchMessage.date == "date")
	}
}
