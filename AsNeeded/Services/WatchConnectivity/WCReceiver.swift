import ANModelKit
import Boutique
import DHLoggingKit
import Foundation
import WatchConnectivity

// MARK: - Watch Message Data Types

/// Sendable wrapper for watch messages to enable safe concurrency
struct SendableMessage: Sendable {
    let getMedications: Bool
    let logDoseData: LogDoseData?
    let quantityUpdateData: QuantityUpdateData?

    init(from message: [String: Any]) {
        getMedications = message["getMedications"] != nil

        if let logDose = message["logDose"] as? [String: Any] {
            logDoseData = LogDoseData(from: logDose)
        } else {
            logDoseData = nil
        }

        if let quantityUpdate = message["updateQuantity"] as? [String: Any] {
            quantityUpdateData = QuantityUpdateData(from: quantityUpdate)
        } else {
            quantityUpdateData = nil
        }
    }
}

/// Data structure for dose logging from watch
struct LogDoseData: Sendable {
    let medicationId: String
    let doseAmount: Double
    let doseUnit: String
    let quantityConsumed: Double?
	let eventID: UUID?
	let date: Date?
	private let invalidRetryMetadata: Bool

	var isValid: Bool {
		!invalidRetryMetadata && UUID(uuidString: medicationId) != nil &&
			ANUnitConcept(rawValue: doseUnit) != nil &&
			doseAmount.isFinite && doseAmount > 0 &&
			(quantityConsumed.map { $0.isFinite && $0 > 0 } ?? true)
	}

    init(from dict: [String: Any]) {
        medicationId = dict["medicationId"] as? String ?? ""
        doseAmount = dict["doseAmount"] as? Double ?? 0.0
        doseUnit = dict["doseUnit"] as? String ?? ""
        quantityConsumed = dict["quantityConsumed"] as? Double
		eventID = (dict["eventID"] as? String).flatMap(UUID.init(uuidString:))
		date = dict["date"] as? Date
		invalidRetryMetadata = (dict["eventID"] != nil && eventID == nil) ||
			(dict["date"] != nil && (date == nil || date?.timeIntervalSince1970.isFinite != true))
    }
}

/// Data structure for quantity updates from watch
struct QuantityUpdateData: Sendable {
    let medicationId: String
    let quantity: Double

	var isValid: Bool {
		UUID(uuidString: medicationId) != nil && quantity.isFinite && quantity >= 0
	}

    init(from dict: [String: Any]) {
        medicationId = dict["medicationId"] as? String ?? ""
		quantity = dict["quantity"] as? Double ?? .nan
    }
}

/// WatchConnectivity's reply callback may be retained until the main-actor save finishes.
private struct WatchMessageReply: @unchecked Sendable {
	let handler: ([String: Any]) -> Void
}

// MARK: - Watch Connectivity Receiver

@MainActor
final class WCReceiver: NSObject, ObservableObject {
    var session: WCSession
    private let logger = DHLogger.network

    @Published var isConnected = false

    // MARK: - Initialization

    override init() {
        session = WCSession.default
        super.init()

        if WCSession.isSupported() {
            session.delegate = self
            session.activate()
        }
    }

    // MARK: - Message Handling

    /// Handle messages from watch in a thread-safe manner
    private nonisolated func handleMessage(_ message: [String: Any], reply: WatchMessageReply? = nil) {
        let sendableMessage = SendableMessage(from: message)
        Task { @MainActor in
			let saved = await self.processMessage(sendableMessage)
			reply?.handler(["saved": saved])
			if reply == nil, !saved, !sendableMessage.getMedications {
				self.session.transferUserInfo(["saveFailed": true])
			}
        }
    }

    private func processMessage(_ message: SendableMessage) async -> Bool {
        do {
			try await MedicationDoseLimitMigration().migrate(dataStore: DataStore.shared)
            if message.getMedications {
                await sendMedicationsToWatch()
				return true
            } else if let logDoseData = message.logDoseData {
				return try await handleDoseLogging(logDoseData)
            } else if let quantityUpdateData = message.quantityUpdateData {
				return try await handleQuantityUpdate(quantityUpdateData)
            }
        } catch {
            logger.logPrivacySafeError("Error handling watch message", error: error)
        }
		return false
    }

    // MARK: - Private Methods

    private func sendMedicationsToWatch() async {
		do {
			try await MedicationDoseLimitMigration().migrate(dataStore: DataStore.shared)
		} catch {
			logger.logPrivacySafeError("Unable to load medication dose limits for watch", error: error)
			return
		}
		let now = Date()
        let medications = DataStore.shared.medications
        let events = DataStore.shared.events
        let safetyProfileStore = MedicationSafetyProfileStore.shared
        let guidanceService = MedicationDoseGuidanceService()

        let medicationData = medications.map { medication -> [String: Any] in
            let profile = safetyProfileStore.profile(for: medication.id)
			let availability = guidanceService.availability(
				for: medication, at: now, events: events, profile: profile
			)
            let refillProjection = guidanceService.refillProjection(
                for: medication,
                events: events,
                profile: profile
            )

            var payload: [String: Any] = [
                "id": medication.id.uuidString,
                "displayName": medication.displayName,
                "quantity": medication.quantity ?? 0.0,
                "prescribedDoseAmount": medication.prescribedDoseAmount ?? 1.0,
                "prescribedUnit": medication.prescribedUnit?.rawValue ?? ANUnitConcept.dose.rawValue,
                "lowStock": refillProjection.lowStock,
                "refillSoon": refillProjection.refillSoon,
            ]

			payload.merge(Self.availabilityFields(for: availability, at: now)) { _, availabilityValue in availabilityValue }

            return payload
        }

        if session.isReachable {
            logger.debug("Sending medications to watch: \(medications.count) medications")
            session.sendMessage(["medications": medicationData], replyHandler: nil) { [weak self] error in
                self?.logger.logPrivacySafeError("Error sending medications to watch", error: error)
            }
        }
    }

	/// Wire fields retain unknown states instead of interpreting a missing date as clearance.
	static func availabilityFields(for availability: MedicationDoseGuidanceService.Availability, at date: Date) -> [String: Any] {
		guard let nextDate = availability.eligibleDate else {
			return ["canTakeNow": false, "statusMessage": availability.message, "statusMessageKey": availability.messageKey]
		}
		return [
			"canTakeNow": nextDate <= date,
			"nextDoseDate": nextDate,
			"statusMessageKey": nextDate > date ? "" : "Saved limits met based on logged doses. Follow your prescription and care instructions.",
			"statusMessage": nextDate > date
				? String(localized: "Next saved window: \(nextDate.formatted(date: .abbreviated, time: .shortened)). Follow your prescription and care instructions.")
				: String(localized: "Saved limits met based on logged doses. Follow your prescription and care instructions.")
		]
	}

    private func handleDoseLogging(_ logDoseData: LogDoseData) async throws -> Bool {
		try await DataStore.shared.prepareForAccess()
		try await MedicationDoseLimitMigration().migrate(dataStore: DataStore.shared)
		guard logDoseData.isValid,
			  let medicationId = UUID(uuidString: logDoseData.medicationId),
			  let doseUnit = ANUnitConcept(rawValue: logDoseData.doseUnit)
        else {
            logger.warning("Invalid dose logging data from watch")
            return false
        }

        // Find the medication
        guard let medication = DataStore.shared.medications.first(where: { $0.id == medicationId }) else {
            logger.warning("Medication not found for dose logging")
            return false
        }

        // Create dose and event
        let dose = ANDoseConcept(amount: logDoseData.doseAmount, unit: doseUnit)
        let event = ANEventConcept(
			id: logDoseData.eventID ?? UUID(),
            eventType: .doseTaken,
            medication: medication,
            dose: dose,
            date: logDoseData.date ?? Date()
        )

        // Log the event
        try await DataStore.shared.recordDose(event)

        // Send confirmation back to watch
        if session.isReachable {
            logger.debug("Dose logged successfully, sending confirmation to watch")
            session.sendMessage(["doseLogged": true], replyHandler: nil) { [weak self] error in
                self?.logger.logPrivacySafeError("Error sending dose confirmation to watch", error: error)
            }
		} else {
			session.transferUserInfo(["doseLogged": true])
        }
		await sendMedicationsToWatch()
		return true
    }

    private func handleQuantityUpdate(_ quantityUpdateData: QuantityUpdateData) async throws -> Bool {
		try await MedicationDoseLimitMigration().migrate(dataStore: DataStore.shared)
		guard quantityUpdateData.isValid,
			  let medicationId = UUID(uuidString: quantityUpdateData.medicationId) else {
            logger.warning("Invalid quantity update data from watch")
            return false
        }

        // Find the medication
		try await DataStore.shared.updateQuantity(medicationID: medicationId, quantity: quantityUpdateData.quantity)

        // Send confirmation back to watch
        if session.isReachable {
            logger.debug("Quantity updated successfully, sending confirmation to watch")
            session.sendMessage(["quantityUpdated": true], replyHandler: nil) { [weak self] error in
                self?.logger.logPrivacySafeError("Error sending quantity update confirmation to watch", error: error)
            }
		} else {
			session.transferUserInfo(["quantityUpdated": true])
        }
		await sendMedicationsToWatch()
		return true
    }
}

// MARK: - WCSessionDelegate

extension WCReceiver: WCSessionDelegate {
    nonisolated func session(_: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in
            if let error = error {
                self.isConnected = false
                self.logger.logPrivacySafeError("WC Session activation failed", error: error)
            } else {
                self.isConnected = (activationState == .activated)
                self.logger.oslog.info("WC Session activated: \(String(describing: activationState), privacy: .public)")
            }
        }
    }

    nonisolated func sessionDidBecomeInactive(_: WCSession) {
        Task { @MainActor in
            self.logger.info("WC Session became inactive")
            self.isConnected = false
        }
    }

    nonisolated func sessionDidDeactivate(_: WCSession) {
        Task { @MainActor in
            self.logger.info("WC Session deactivated")
            self.isConnected = false
        }
    }

    nonisolated func session(_: WCSession, didReceiveMessage message: [String: Any]) {
        Task { @MainActor in
            self.logger.debug("Received message from watch")
        }
        handleMessage(message)
    }

    nonisolated func session(_: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        Task { @MainActor in
            self.logger.debug("Received message from watch with reply handler")
        }
		handleMessage(message, reply: WatchMessageReply(handler: replyHandler))
    }

    nonisolated func session(_: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        Task { @MainActor in
            self.logger.debug("Received user info from watch")
        }
        handleMessage(userInfo)
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        let isReachable = session.isReachable
        Task { @MainActor in
            self.isConnected = isReachable
            self.logger.oslog.info("Session reachability changed: \(isReachable, privacy: .public)")

            // If reachable and watch requested medications, send them
            if isReachable {
                await self.sendMedicationsToWatch()
            }
        }
    }
}
