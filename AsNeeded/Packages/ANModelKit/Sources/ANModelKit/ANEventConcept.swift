import Foundation

/// Types of events that can be logged for medication or dose.
public enum ANEventType: String, Codable, CaseIterable, Equatable, Hashable {
    case doseTaken = "dose_taken"
    case reconcile = "reconcile"
    // Extend with more event types as needed
}

/// Represents a logged event (such as a dose taken, or a reconciliation).
public struct ANEventConcept: Identifiable, Codable, Equatable, Hashable {
    /// Unique identifier for this event
    public let id: UUID
    /// The type of event (e.g., dose taken, reconcile)
    public var eventType: ANEventType
    /// The medication concept involved in the event (optional)
    public var medication: ANMedicationConcept?
    /// The dose concept involved in the event (optional)
    public var dose: ANDoseConcept?
    /// The date of the event
    public var date: Date

    /// Initialize a new event concept
    public init(
        id: UUID = UUID(),
        eventType: ANEventType,
        medication: ANMedicationConcept? = nil,
        dose: ANDoseConcept? = nil,
        date: Date = Date()
    ) {
        self.id = id
        self.eventType = eventType
        self.medication = medication
        self.dose = dose
        self.date = date
    }
}
