import Foundation
import Testing
@testable import SwiftRxNorm

@Suite("RxNormConstants Tests")
struct RxNormConstantsTests {
	
	@Test("Required disclaimer is available and not empty")
	func testRequiredDisclaimer() {
		let disclaimer = RxNormConstants.requiredDisclaimer
		#expect(!disclaimer.isEmpty)
		#expect(disclaimer.contains("National Library of Medicine"))
		#expect(disclaimer.contains("NLM"))
	}
	
	@Test("Short disclaimer is available")
	func testShortDisclaimer() {
		let disclaimer = RxNormConstants.shortDisclaimer
		#expect(!disclaimer.isEmpty)
		#expect(disclaimer.contains("RxNorm"))
	}
	
	@Test("Medical disclaimer is available")
	func testMedicalDisclaimer() {
		let disclaimer = RxNormConstants.medicalDisclaimer
		#expect(!disclaimer.isEmpty)
		#expect(disclaimer.contains("medical advice"))
	}
	
	@Test("Full disclaimer combines both disclaimers")
	func testFullDisclaimer() {
		let fullDisclaimer = RxNormConstants.fullDisclaimer
		#expect(fullDisclaimer.contains(RxNormConstants.requiredDisclaimer))
		#expect(fullDisclaimer.contains(RxNormConstants.medicalDisclaimer))
	}
	
	@Test("API URLs are properly formatted")
	func testAPIURLs() {
		#expect(RxNormConstants.termsOfServiceURL.hasPrefix("https://"))
		#expect(RxNormConstants.apiDocumentationURL.hasPrefix("https://"))
	}
}