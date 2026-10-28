import ANModelKit
@testable import AsNeeded
import Foundation
import Testing

@MainActor
@Suite("Retired question settings", .tags(.unit, .dataManagement))
struct RetiredQuestionSettingsTests {
	@Test("Older settings decode without restoring or re-exporting retired questions")
	func legacySettingsStayCompatible() throws {
		let legacy = Data(#"{"trendsQuestionsEnabled":true,"hapticsEnabled":false,"selectedFontFamily":"OpenDyslexic"}"#.utf8)
		let settings = try JSONDecoder().decode(AppSettings.self, from: legacy)
		let suite = "RetiredQuestions.\(UUID().uuidString)"
		let defaults = try #require(UserDefaults(suiteName: suite))
		defer { defaults.removePersistentDomain(forName: suite) }
		settings.apply(to: defaults, validateMedicationIDs: { [] })
		#expect(defaults.object(forKey: UserDefaultsKeys.hapticsEnabled) as? Bool == false)
		#expect(defaults.string(forKey: UserDefaultsKeys.selectedFontFamily) == "OpenDyslexic")
		#expect(!defaults.dictionaryRepresentation().keys.contains("trendsQuestionsEnabled"))
		let encoded = try JSONEncoder().encode(settings)
		let object = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
		#expect(object["trendsQuestionsEnabled"] == nil)
	}

	@Test("A retired question flag alone adds no settings category")
	func noRetiredCategory() throws {
		let settings = try JSONDecoder().decode(AppSettings.self, from: Data(#"{"trendsQuestionsEnabled":true}"#.utf8))
		#expect(settings.settingsCategories.isEmpty)
	}

	@Test("An older export retains medication data while ignoring retired settings")
	func legacyMedicationExportRemainsReadable() throws {
		let legacy = Data(#"{"medications":[{"id":"00000000-0000-0000-0000-000000000001","clinicalName":"Synthetic medication","quantity":10}],"events":[],"exportDate":"2026-10-27T12:00:00Z","appVersion":"1.1.2","dataVersion":"1.0","settings":{"trendsQuestionsEnabled":true,"hapticsEnabled":false}}"#.utf8)
		let decoder = JSONDecoder()
		decoder.dateDecodingStrategy = .iso8601
		let exported = try decoder.decode(DataExport.self, from: legacy)
		#expect(exported.medications.count == 1)
		#expect(exported.medications.first?.quantity == 10)
		#expect(exported.settings?.hapticsEnabled == false)
		#expect(exported.events.isEmpty)
	}
	@Test("Existing obsolete preferences are ignored by new settings exports")
	func existingPreferenceIsNotExported() throws {
		let suite = "RetiredQuestions.\(UUID().uuidString)"
		let defaults = try #require(UserDefaults(suiteName: suite))
		defer { defaults.removePersistentDomain(forName: suite) }
		defaults.setPersistentDomain(["trendsQuestionsEnabled": true, UserDefaultsKeys.hapticsEnabled: true], forName: suite)
		let settings = AppSettings(from: defaults)
		let encoded = try JSONEncoder().encode(settings)
		let object = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
		#expect(object["trendsQuestionsEnabled"] == nil)
		#expect(settings.hapticsEnabled == true)
	}

}
