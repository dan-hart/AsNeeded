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

    init(from dict: [String: Any]) {
        medicationId = dict["medicationId"] as? String ?? ""
        doseAmount = dict["doseAmount"] as? Double ?? 0.0
        doseUnit = dict["doseUnit"] as? String ?? ""
        quantityConsumed = dict["quantityConsumed"] as? Double
    }
}

/// Data structure for quantity updates from watch
struct QuantityUpdateData: Sendable {
    let medicationId: String
    let quantity: Double

    init(from dict: [String: Any]) {
        medicationId = dict["medicationId"] as? String ?? ""
        quantity = dict["quantity"] as? Double ?? 0.0
    }
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
    private nonisolated func handleMessage(_ message: [String: Any]) {
        let sendableMessage = SendableMessage(from: message)
        Task { @MainActor in
            await self.processMessage(sendableMessage)
        }
    }

    private func processMessage(_ message: SendableMessage) async {
        do {
            if message.getMedications {
                await sendMedicationsToWatch()
            } else if let logDoseData = message.logDoseData {
                try await handleDoseLogging(logDoseData)
            } else if let quantityUpdateData = message.quantityUpdateData {
                try await handleQuantityUpdate(quantityUpdateData)
            }
        } catch {
            logger.error("Error handling watch message", error: error)
        }
    }

    // MARK: - Private Methods

    private func sendMedicationsToWatch() async {
        let medications = DataStore.shared.medications
        let events = DataStore.shared.events
        let safetyProfileStore = MedicationSafetyProfileStore.shared
        let guidanceService = MedicationDoseGuidanceService()

        let medicationData = medications.map { medication -> [String: Any] in
            let profile = safetyProfileStore.profile(for: medication.id)
            let nextDoseDate = guidanceService.nextEligibleDate(
                for: medication,
                events: events,
                profile: profile
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
                "canTakeNow": nextDoseDate == nil || nextDoseDate ?? .distantPast <= Date(),
                "lowStock": refillProjection.lowStock,
                "refillSoon": refillProjection.refillSoon,
                "statusMessage": refillProjection.statusMessage,
            ]

            if let nextDoseDate {
                payload["nextDoseDate"] = nextDoseDate
            }

            return payload
        }

        if session.isReachable {
            logger.debug("Sending medications to watch: \(medications.count) medications")
            session.sendMessage(["medications": medicationData], replyHandler: nil) { [weak self] error in
                self?.logger.error("Error sending medications to watch", error: error)
            }
        }
    }

    private func handleDoseLogging(_ logDoseData: LogDoseData) async throws {
        guard let medicationId = UUID(uuidString: logDoseData.medicationId),
              let doseUnit = ANUnitConcept(rawValue: logDoseData.doseUnit)
        else {
            logger.oslog.warning("Invalid dose logging data from watch: medicationId=\(logDoseData.medicationId, privacy: .private) doseUnit=\(logDoseData.doseUnit, privacy: .public)")
            return
        }

        // Find the medication
        guard let medication = DataStore.shared.medications.first(where: { $0.id == medicationId }) else {
            logger.oslog.warning("Medication not found for dose logging: medicationId=\(medicationId, privacy: .private)")
            return
        }

        // Create dose and event
        let dose = ANDoseConcept(amount: logDoseData.doseAmount, unit: doseUnit)
        let event = ANEventConcept(
            eventType: .doseTaken,
            medication: medication,
            dose: dose,
            date: Date()
        )

        // Log the event
        try await DataStore.shared.addEvent(event)

        // Update medication quantity if provided
        if let quantityConsumed = logDoseData.quantityConsumed,
           let currentQuantity = medication.quantity
        {
            // Use mutation to preserve all medication properties (color, symbol, etc.)
            var updatedMedication = medication
            updatedMedication.quantity = max(0, currentQuantity - quantityConsumed)
            try await DataStore.shared.updateMedication(updatedMedication)
        }

        // Send confirmation back to watch
        await MedicationLiveActivityManager.refreshFromDataStore()

        if session.isReachable {
            logger.debug("Dose logged successfully, sending confirmation to watch")
            session.sendMessage(["doseLogged": true], replyHandler: nil) { [weak self] error in
                self?.logger.error("Error sending dose confirmation to watch", error: error)
            }
        }
    }

    private func handleQuantityUpdate(_ quantityUpdateData: QuantityUpdateData) async throws {
        guard let medicationId = UUID(uuidString: quantityUpdateData.medicationId) else {
            logger.oslog.warning("Invalid quantity update data from watch: medicationId=\(quantityUpdateData.medicationId, privacy: .private)")
            return
        }

        // Find the medication
        guard let medication = DataStore.shared.medications.first(where: { $0.id == medicationId }) else {
            logger.oslog.warning("Medication not found for quantity update: medicationId=\(medicationId, privacy: .private)")
            return
        }

        // Update medication quantity using mutation to preserve all properties (color, symbol, etc.)
        var updatedMedication = medication
        updatedMedication.quantity = quantityUpdateData.quantity
        try await DataStore.shared.updateMedication(updatedMedication)

        // Send confirmation back to watch
        await MedicationLiveActivityManager.refreshFromDataStore()

        if session.isReachable {
            logger.oslog.debug("Quantity updated successfully: \(quantityUpdateData.quantity, privacy: .public), sending confirmation to watch")
            session.sendMessage(["quantityUpdated": true], replyHandler: nil) { [weak self] error in
                self?.logger.error("Error sending quantity update confirmation to watch", error: error)
            }
        }
    }
}

// MARK: - WCSessionDelegate

extension WCReceiver: WCSessionDelegate {
    nonisolated func session(_: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in
            if let error = error {
                self.isConnected = false
                self.logger.error("WC Session activation failed", error: error)
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
        handleMessage(message)
        replyHandler(["received": true])
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
