import ANModelKit
@testable import AsNeeded
import Foundation
import Testing

@MainActor
struct LocalizedFractionalQuantityTests {
	struct Input: Sendable {
		let localeID: String
		let stock: String
		let refill: String
		let prescribed: String
		let logged: String
		let edited: String
		let watchStock: String
	}

	@Test("Localized fractional amounts survive logging, History edits, Watch decoding and restore", arguments: [
		Input(localeID: "fr_FR", stock: "12,875", refill: "31,375", prescribed: "0,625", logged: "1,125", edited: "0,375", watchStock: "12,6875"),
		Input(localeID: "ar_SA", stock: "١٢٫٨٧٥", refill: "٣١٫٣٧٥", prescribed: "٠٫٦٢٥", logged: "١٫١٢٥", edited: "٠٫٣٧٥", watchStock: "١٢٫٦٨٧٥"),
	])
	func localizedRoundTrip(_ input: Input) async throws {
		let locale = Locale(identifier: input.localeID)
		let preferences = try IsolatedTestPreferences()
		let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
		defer { try? FileManager.default.removeItem(at: directory) }
		let store = DataStore(storageDirectory: directory.appendingPathComponent("source"),
			defaults: preferences.defaults, defaultsDomainName: preferences.name)
		let editor = MedicationEditViewModel(medication: nil,
			safetyProfileStore: MedicationSafetyProfileStore(defaults: preferences.defaults), locale: locale)
		editor.clinicalName = "Synthetic fractional medication"
		editor.quantityText = input.stock
		editor.initialQuantityText = input.refill
		editor.prescribedDoseText = input.prescribed
		editor.prescribedUnit = .tablet
		let saved = await editor.saveMedication { medication in
			do {
				try await store.addMedication(medication)
				return true
			} catch {
				Issue.record(error)
				return false
			}
		}
		try #require(saved)
		let medication = try #require(store.medications.first)
		#expect(medication.quantity == 12.875)
		#expect(medication.initialQuantity == 31.375)
		#expect(medication.prescribedDoseAmount == 0.625)
		#expect(medication.prescribedUnit == .tablet)

		let date = Date(timeIntervalSince1970: 1_790_000_000)
		let appDose = ANDoseConcept(amount: DoseAmountInput.parse(input.logged, locale: locale), unit: .tablet)
		let appEvent = ANEventConcept(eventType: .doseTaken, medication: medication, dose: appDose, date: date)
		let detail = MedicationDetailViewModel(dataStore: store)
		try #require(await detail.logDose(medication: medication, dose: appDose, event: appEvent, source: "localized_fraction_test"))
		#expect(store.events.first?.dose?.amount == 1.125)
		#expect(store.medications.first?.quantity == 11.75)

		let keys = SharedPlatformContracts.WatchMessage.self
		let quantity = try #require(DoseAmountInput.value(from: input.watchStock, locale: locale))
		let update = try #require(SendableMessage(from: [keys.updateQuantity: [keys.medicationId: medication.id.uuidString, keys.quantity: quantity]]).quantityUpdateData)
		#expect(update.isValid)
		#expect(update.quantity == 12.6875)
		try await store.updateQuantity(medicationID: medication.id, quantity: update.quantity)
		#expect(store.medications.first?.quantity == 12.6875)
		let watchID = UUID()
		let watchDate = date.addingTimeInterval(60)
		let payload: [String: Any] = [keys.medicationId: medication.id.uuidString, keys.eventID: watchID.uuidString,
			keys.date: watchDate, keys.doseAmount: try #require(medication.prescribedDoseAmount), keys.doseUnit: ANUnitConcept.tablet.rawValue]
		let watchDose = try #require(SendableMessage(from: [keys.logDose: payload]).logDoseData)
		#expect(watchDose.doseAmount == 0.625)
		try #require(try await WCReceiver.recordDose(watchDose, in: store, migrate: { _ in }))
		#expect(store.medications.first?.quantity == 12.0625)

		let history = MedicationHistoryViewModel(dataStore: store, selectedMedicationID: medication.id.uuidString, defaults: preferences.defaults)
		let editedAmount = DoseAmountInput.parse(input.edited, locale: locale)
		try #require(await history.updateEvent(appEvent, newDate: date, newAmount: editedAmount, newUnit: .tablet))
		let entries = history.groupedHistory.flatMap(\.entries)
		#expect(entries.first(where: { $0.id == appEvent.id })?.dose?.amount == 0.375)
		#expect(entries.first(where: { $0.id == watchID })?.dose?.amount == 0.625)
		#expect(store.medications.first?.quantity == 12.8125)

		let backup = try await store.exportDataAsJSON()
		let restoredDirectory = directory.appendingPathComponent("restored")
		let restored = DataStore(storageDirectory: restoredDirectory, defaults: preferences.defaults, defaultsDomainName: preferences.name)
		try await restored.importDataFromJSON(backup)
		let reopened = DataStore(storageDirectory: restoredDirectory, defaults: preferences.defaults, defaultsDomainName: preferences.name)
		let snapshot = try await reopened.prepareForAccess()
		let restoredMedication = try #require(snapshot.medications.first)
		#expect(restoredMedication.id == medication.id)
		#expect(restoredMedication.quantity == 12.8125)
		#expect(restoredMedication.initialQuantity == 31.375)
		#expect(restoredMedication.prescribedDoseAmount == 0.625)
		#expect(restoredMedication.prescribedUnit == .tablet)
		#expect(Set(snapshot.events.map(\.id)) == [appEvent.id, watchID])
		let app = try #require(snapshot.events.first { $0.id == appEvent.id })
		let watch = try #require(snapshot.events.first { $0.id == watchID })
		#expect(app.dose?.amount == 0.375)
		#expect(watch.dose?.amount == 0.625)
		#expect([app.date, watch.date] == [date, watchDate])
		#expect(snapshot.events.allSatisfy { $0.dose?.unit == .tablet && $0.medication?.id == medication.id })
	}
}
