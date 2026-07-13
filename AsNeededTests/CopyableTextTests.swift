@testable import AsNeeded
import Testing

@Suite("Copyable Text Tests", .tags(Tag.medication, Tag.unit))
struct CopyableTextTests {
	@Test("Includes the complete clinical name in the copy action")
	func accessibilityCopyActionName() {
		let clinicalName = "Acetaminophen and Hydrocodone Bitartrate Extended-Release"

		#expect(
			CopyableText.accessibilityCopyActionName(for: clinicalName)
				== "Copy clinical name: Acetaminophen and Hydrocodone Bitartrate Extended-Release"
		)
	}
}
