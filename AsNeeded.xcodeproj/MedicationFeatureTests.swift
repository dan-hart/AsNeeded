import Foundation
import Testing
import Boutique
@testable import YourApp

@Suite("Medication Feature Suite")
struct MedicationFeatureTests {
	@Test("Can insert and fetch a medication")
	func insertFetchMedication() async throws {
		let store = Store<Medication>(storage: .memoryOnly, cacheIdentifier: \Medication.id)
		let med = Medication(name: "Ibuprofen", dosage: "200mg", asNeeded: true, info: "Pain relief", rxCUI: "5640", history: [])
		try await store.upsert(med)
		let fetched = store.items.first(where: { $0.id == med.id })
		#expect(fetched == med)
	}
	
	@Test("Can update and delete medication")
	func updateDeleteMedication() async throws {
		let store = Store<Medication>(storage: .memoryOnly, cacheIdentifier: \Medication.id)
		var med = Medication(name: "Aspirin", dosage: "325mg", asNeeded: false, info: "Blood thinner", rxCUI: "1191", history: [])
		try await store.upsert(med)
		med.dosage = "500mg"
		try await store.upsert(med)
		let updated = store.items.first(where: { $0.id == med.id })
		#expect(updated?.dosage == "500mg")
		try await store.remove(med)
		#expect(store.items.contains(where: { $0.id == med.id }) == false)
	}
	
	@Test("mostRecentTaken returns latest date")
	func mostRecentTakenTest() async throws {
		let now = Date()
		let past = now.addingTimeInterval(-3600*24)
		let med = Medication(name: "Albuterol", dosage: nil, asNeeded: true, info: "Asthma", rxCUI: "435", history: [past, now])
		#expect(med.mostRecentTaken == now)
	}
}
