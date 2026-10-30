import ANModelKit
@testable import AsNeeded
import Testing

@MainActor
struct MedicationEditSessionTests {
	@Test("Recreating a presented editor retains its draft and discard baseline")
	func retainedDraft() {
		let session = MedicationEditViewModel.Session()
		let draft = session.draft(for: nil)
		draft.originalDraft = [""]
		draft.clinicalName = "Example medication"
		draft.nickname = "Unsaved example"
		draft.quantityText = "12.5"
		draft.showingSaveError = true
		let recreated = session.draft(for: nil)
		#expect(recreated === draft)
		#expect(recreated.clinicalName == "Example medication")
		#expect(recreated.nickname == "Unsaved example")
		#expect(recreated.quantityText == "12.5")
		#expect(recreated.originalDraft == [""])
		#expect(recreated.showingSaveError)
	}

	@Test("Dismissing an editor starts the next add with a fresh draft")
	func dismissedDraftIsCleared() {
		let session = MedicationEditViewModel.Session()
		let previous = session.draft(for: nil)
		previous.clinicalName = "Previous example"
		session.reset()
		let next = session.draft(for: nil)
		#expect(next !== previous)
		#expect(next.clinicalName.isEmpty)
		#expect(next.originalDraft == nil)
		#expect(!next.showingSaveError)
	}

	@Test("The same medication keeps edits while a different medication starts separately")
	func medicationIdentity() {
		let session = MedicationEditViewModel.Session()
		let first = ANMedicationConcept(clinicalName: "First example", quantity: 10.5)
		let second = ANMedicationConcept(clinicalName: "Second example")
		let draft = session.draft(for: first)
		draft.nickname = "Unsaved nickname"
		#expect(session.draft(for: first) === draft)
		#expect(session.draft(for: first).buildMedication().id == first.id)
		var externallyUpdated = first
		externallyUpdated.quantity = 10
		#expect(session.draft(for: externallyUpdated) === draft)
		#expect(draft.originalMedication?.quantity == 10.5, "Rehosting must retain the original stock-edit baseline")
		let other = session.draft(for: second)
		#expect(other !== draft)
		#expect(other.nickname != "Unsaved nickname")
		#expect(other.buildMedication().id == second.id)
	}
	@Test("A suspended save cannot be submitted again by a rehosted editor")
	func suspendedSaveIsNotDuplicated() async throws {
		let session = MedicationEditViewModel.Session()
		let draft = session.draft(for: nil)
		draft.clinicalName = "Example medication"
		try #require(draft.isFormValid)
		let started = AsyncStream<Void>.makeStream()
		let result = AsyncStream<Bool>.makeStream()
		defer { started.continuation.finish(); result.continuation.finish() }
		var calls = 0
		let pending = Task {
			await draft.saveMedication { _ in
				calls += 1
				started.continuation.yield(())
				var replies = result.stream.makeAsyncIterator()
				return await replies.next() ?? false
			}
		}
		var starts = started.stream.makeAsyncIterator()
		_ = await starts.next()
		let rehosted = session.draft(for: nil)
		#expect(rehosted.isSaving)
		_ = await rehosted.saveMedication { _ in calls += 1; return false }
		#expect(calls == 1, "The first save is still pending; rehosting must not permit another write")
		result.continuation.yield(false)
		#expect(await pending.value == false)
		#expect(!rehosted.isSaving)
		_ = await rehosted.saveMedication { _ in calls += 1; return false }
		#expect(calls == 2, "A failed save permits one deliberate retry after completion")
	}

}
