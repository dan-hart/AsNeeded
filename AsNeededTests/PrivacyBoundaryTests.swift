import ANModelKit
@testable import AsNeeded
import DHLoggingKit
import Foundation
import SwiftRxNorm
import Testing

@MainActor
struct PrivacyBoundaryTests {
	private struct SyntheticFailure: LocalizedError, CustomStringConvertible {
		let payload: String
		var errorDescription: String? { payload }
		var description: String { payload }
	}

	private actor RecordingRxNormTransport: RxNormNetworking {
		private(set) var requests: [URLRequest] = []

		func data(for request: URLRequest) async throws -> (Data, URLResponse) {
			requests.append(request)
			throw URLError(.notConnectedToInternet)
		}
	}

	@Test("Diagnostic error labels omit error text, URLs, and identifiers")
	func diagnosticErrorLabelOmitsPayload() {
		let payload = "SyntheticDoseNote https://synthetic.invalid/SyntheticMedication/SyntheticRecordID"
		let failure = SyntheticFailure(payload: payload)
		#expect(failure.localizedDescription == payload)
		let label = DHLogger.privacySafeErrorType(failure)
		#expect(label.hasSuffix(".SyntheticFailure"))
		for privateValue in ["SyntheticDoseNote", "synthetic.invalid", "SyntheticMedication", "SyntheticRecordID"] {
			#expect(!label.contains(privateValue))
		}
		#expect(DHLogger.privacySafeErrorType(nil) == "unknown")
	}

	@Test("RxNorm receives only the active lookup over HTTPS with no record payload")
	func rxNormReceivesOnlyActiveLookup() async throws {
		let preferences = try IsolatedTestPreferences()
		let recent = "SyntheticPrivatePreviousLookup"
		preferences.defaults.set([recent], forKey: UserDefaultsKeys.recentMedicationSearches)
		let transport = RecordingRxNormTransport()
		let client = RxNormClient(network: transport)
		let service = MedicationSearchService(
			defaults: preferences.defaults,
			enhancedSearch: { try await client.enhancedSearch($0) },
			autocomplete: { try await client.autocomplete($0) }
		)
		let query = "SyntheticPublicLookup"

		_ = await service.searchMedicationsEnhanced(" \(query)\n")
		_ = await service.autocomplete(" \(query)\n")

		let requests = await transport.requests
		try #require(!requests.isEmpty)
		for request in requests {
			let url = try #require(request.url)
			let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
			let fields = components.queryItems ?? []
			#expect(components.scheme == "https")
			#expect(components.host == "rxnav.nlm.nih.gov")
			#expect(components.path.hasPrefix("/REST/"))
			#expect(request.httpMethod == "GET")
			#expect(request.httpBody == nil)
			#expect(request.httpBodyStream == nil)
			#expect(!url.absoluteString.contains(recent))
			#expect(request.allHTTPHeaderFields?.values.contains { $0.contains(recent) } != true)
			#expect(fields.contains { $0.value == query })
			#expect(fields.allSatisfy { ["name", "term", "maxEntries", "option"].contains($0.name) })
		}
	}

	@Test("Redacted share data removes medication names, event notes, and recent lookup text")
	func redactedExportOmitsSyntheticPrivateData() async throws {
		let preferences = try IsolatedTestPreferences()
		let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
		defer { try? FileManager.default.removeItem(at: directory) }
		let store = DataStore(storageDirectory: directory, defaults: preferences.defaults, defaultsDomainName: preferences.name)
		let name = "SyntheticPrivateMedicationName"
		let nickname = "SyntheticPrivateNickname"
		let note = "SyntheticPrivateDoseNote"
		let search = "SyntheticPrivateLookup"
		let medication = ANMedicationConcept(clinicalName: name, nickname: nickname)
		let event = ANEventConcept(eventType: .doseTaken, medication: medication,
			dose: ANDoseConcept(amount: 1, unit: .tablet), date: Date(timeIntervalSince1970: 1_700_000_000), note: note)
		try await store.addMedication(medication)
		try await store.addEvent(event, shouldRecordForReview: false)
		preferences.defaults.set([search], forKey: UserDefaultsKeys.recentMedicationSearches)

		let original = try await store.exportDataAsJSON(includeSettings: true)
		let redacted = try await store.exportDataAsJSON(redactNames: true, redactNotes: true, includeSettings: true)
		let originalText = String(decoding: original, as: UTF8.self)
		let redactedText = String(decoding: redacted, as: UTF8.self)
		for sentinel in [name, nickname, note, search] {
			#expect(originalText.contains(sentinel))
			#expect(!redactedText.contains(sentinel))
		}
		let decoder = JSONDecoder()
		decoder.dateDecodingStrategy = .iso8601
		let export = try decoder.decode(DataExport.self, from: redacted)
		#expect(export.medications.count == 1)
		#expect(export.events.count == 1)
		#expect(export.events.first?.dose?.amount == 1)
	}
}
