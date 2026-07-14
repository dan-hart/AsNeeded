@testable import AsNeeded
import Testing

#if canImport(ActivityKit)
	@Suite("MedicationLiveActivityCleanup Tests", .tags(.unit))
	struct MedicationLiveActivityCleanupTests {
		private final class MockSession: MedicationLiveActivitySession, @unchecked Sendable {
			var endCount = 0

			func end() async {
				endCount += 1
			}
		}

		private struct MockClient: MedicationLiveActivityClient, @unchecked Sendable {
			let storedSessions: [MockSession]

			func sessions() -> [any MedicationLiveActivitySession] {
				storedSessions
			}
		}

		@Test("Cleanup immediately ends every activity left by an earlier build")
		func cleanupEndsEveryExistingActivity() async {
			let firstSession = MockSession()
			let secondSession = MockSession()
			let client = MockClient(storedSessions: [firstSession, secondSession])

			await MedicationLiveActivityCleanup.endAll(liveActivityClient: client)

			#expect(firstSession.endCount == 1)
			#expect(secondSession.endCount == 1)
		}
	}
#endif
