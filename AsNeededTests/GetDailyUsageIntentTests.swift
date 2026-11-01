@testable import ANModelKit
@testable import AsNeeded
import Foundation
import Testing

@MainActor
@Suite(.tags(.intent, .unit))
struct GetDailyUsageIntentTests {
    @Test("Intent has correct metadata")
    func intentHasCorrectMetadata() {
        #expect(GetDailyUsageIntent.title == "Get Daily Medication Usage")
        #expect(GetDailyUsageIntent.openAppWhenRun == false)
    }

    @Test("calculateTodayUsage returns zero for medication with no events")
    func calculateTodayUsageReturnsZeroForMedicationWithNoEvents() {
        let intent = GetDailyUsageIntent()
        let medication = ANMedicationConcept(clinicalName: "Test Med", prescribedUnit: .tablet)

        let result = intent.calculateTodayUsage(for: medication)

        #expect(result.totalAmount == 0.0)
        #expect(result.unit == .tablet)
        #expect(result.doseCount == 0)
    }

    @Test("calculateTodayUsage uses default unit when no prescribed unit")
    func calculateTodayUsageUsesDefaultUnitWhenNoPrescribedUnit() {
        let intent = GetDailyUsageIntent()
        let medication = ANMedicationConcept(clinicalName: "Test Med")

        let result = intent.calculateTodayUsage(for: medication)

        #expect(result.totalAmount == 0.0)
        #expect(result.unit == .unit)
        #expect(result.doseCount == 0)
    }

    @Test("Intent can be initialized")
    func intentCanBeInitialized() {
        let intent = GetDailyUsageIntent()
        #expect(intent.medication == nil)
        #expect(intent.medicationName == nil)
    }

    @Test("Intent parameters can be set")
    func intentParametersCanBeSet() {
        let intent = GetDailyUsageIntent()
        intent.medicationName = "Aspirin"

        #expect(intent.medicationName == "Aspirin")
        #expect(intent.medication == nil)
    }
}

@MainActor
@Suite("Cold medication intent snapshots", .tags(.intent, .persistence, .unit))
struct ColdMedicationIntentTests {
	enum ExpectedFailure: Error { case read }

	@Test("Every cold intent and entity query waits for persistence and propagates read failures")
	func coldReadersAwaitPersistence() async throws {
		let preferences = try IsolatedTestPreferences()
		let store = DataStore(storageDirectory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString), defaults: preferences.defaults, defaultsDomainName: preferences.name, navigationManager: NavigationManager(defaults: preferences.defaults), transactionFault: { phase in
			if phase == .beforeLock { throw ExpectedFailure.read }
		})
		await #expect(throws: ExpectedFailure.self) { _ = try await ListMedicationsIntent(dataStore: store).perform() }
		await #expect(throws: ExpectedFailure.self) { _ = try await CheckRefillStatusIntent(dataStore: store).perform() }
		await #expect(throws: ExpectedFailure.self) { _ = try await GetDailyUsageIntent(dataStore: store).perform() }
		let query = MedicationQuery(dataStore: store)
		await #expect(throws: ExpectedFailure.self) { _ = try await query.entities(for: []) }
		await #expect(throws: ExpectedFailure.self) { _ = try await query.entities(matching: "Synthetic") }
		await #expect(throws: ExpectedFailure.self) { _ = try await query.suggestedEntities() }
	}

	@Test("Cold queries reopen persisted medications and history using a current entity")
	func coldQueriesReopenPersistedSnapshot() async throws {
		let preferences = try IsolatedTestPreferences()
		let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
		let navigation = NavigationManager(defaults: preferences.defaults)
		let writer = DataStore(storageDirectory: directory, defaults: preferences.defaults, defaultsDomainName: preferences.name, navigationManager: navigation)
		var medication = ANMedicationConcept(clinicalName: "Z Synthetic", prescribedUnit: .tablet)
		let staleEntity = MedicationEntity(medication: medication)
		let other = ANMedicationConcept(clinicalName: "A Synthetic")
		try await writer.addMedication(medication)
		try await writer.addMedication(other)
		let now = Date()
		try await writer.addEvent(ANEventConcept(eventType: .doseTaken, medication: medication, dose: ANDoseConcept(amount: 0.5, unit: .tablet), date: now))
		medication.nickname = "Current synthetic"
		try await writer.updateMedication(medication)
		let reader = DataStore(storageDirectory: directory, defaults: preferences.defaults, defaultsDomainName: preferences.name, navigationManager: navigation)
		let query = MedicationQuery(dataStore: reader)
		let entities = try await query.entities(for: [medication.id.uuidString.lowercased()])
		#expect(entities.map(\.displayName) == ["Current synthetic"])
		#expect(try await query.entities(matching: "CURRENT").map(\.id) == [medication.id.uuidString])
		#expect(try await query.suggestedEntities().map(\.id) == [medication.id.uuidString, other.id.uuidString])
		let intent = GetDailyUsageIntent(dataStore: reader)
		intent.medication = staleEntity
		let snapshot = try await reader.prepareForAccess()
		let current = try #require(intent.resolveMedication(in: snapshot.medications))
		#expect(current.displayName == "Current synthetic")
		let usage = intent.calculateTodayUsage(for: current, events: snapshot.events, at: now)
		#expect(usage.totalAmount == 0.5)
		#expect(usage.doseCount == 1)
		#expect(intent.resolveMedication(in: []) == nil)
		_ = try await ListMedicationsIntent(dataStore: reader).perform()
		_ = try await CheckRefillStatusIntent(dataStore: reader).perform()
		_ = try await intent.perform()
	}

	@Test("Daily usage handles large quantities without integer conversion")
	func largeDailyUsageDoesNotTrap() async throws {
		let preferences = try IsolatedTestPreferences()
		let store = DataStore(storageDirectory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString), defaults: preferences.defaults, defaultsDomainName: preferences.name, navigationManager: NavigationManager(defaults: preferences.defaults))
		let medication = ANMedicationConcept(clinicalName: "Synthetic large amount", prescribedUnit: .tablet)
		try await store.addMedication(medication)
		try await store.addEvent(ANEventConcept(eventType: .doseTaken, medication: medication, dose: ANDoseConcept(amount: 1e100, unit: .tablet)))
		let intent = GetDailyUsageIntent(dataStore: store)
		intent.medication = MedicationEntity(medication: medication)
		_ = try await intent.perform()
	}
}
