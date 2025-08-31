import WatchConnectivity
import Foundation
import Boutique
import ANModelKit

// MARK: - Watch Message Data Types

/// Sendable wrapper for watch messages to enable safe concurrency
struct SendableMessage: Sendable {
	let getMedications: Bool
	let logDoseData: LogDoseData?
	let quantityUpdateData: QuantityUpdateData?
	
	init(from message: [String: Any]) {
		self.getMedications = message["getMedications"] != nil
		
		if let logDose = message["logDose"] as? [String: Any] {
			self.logDoseData = LogDoseData(from: logDose)
		} else {
			self.logDoseData = nil
		}
		
		if let quantityUpdate = message["updateQuantity"] as? [String: Any] {
			self.quantityUpdateData = QuantityUpdateData(from: quantityUpdate)
		} else {
			self.quantityUpdateData = nil
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
		self.medicationId = dict["medicationId"] as? String ?? ""
		self.doseAmount = dict["doseAmount"] as? Double ?? 0.0
		self.doseUnit = dict["doseUnit"] as? String ?? ""
		self.quantityConsumed = dict["quantityConsumed"] as? Double
	}
}

/// Data structure for quantity updates from watch
struct QuantityUpdateData: Sendable {
	let medicationId: String
	let quantity: Double
	
	init(from dict: [String: Any]) {
		self.medicationId = dict["medicationId"] as? String ?? ""
		self.quantity = dict["quantity"] as? Double ?? 0.0
	}
}

// MARK: - Watch Connectivity Receiver

@MainActor
final class WCReceiver: NSObject, ObservableObject {
	var session: WCSession
	
	@Published var isConnected = false
	
	// MARK: - Initialization

	override init() {
		self.session = WCSession.default
		super.init()
		
		if WCSession.isSupported() {
			self.session.delegate = self
			self.session.activate()
		}
	}
	
	// MARK: - Message Handling

	/// Handle messages from watch in a thread-safe manner
	nonisolated private func handleMessage(_ message: [String: Any]) {
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
			print("ERROR: Error handling watch message \(error)")
		}
	}
	
	// MARK: - Private Methods

	private func sendMedicationsToWatch() async {
		let medications = DataStore.shared.medications
		
		let medicationData = medications.map { medication in
			[
				"id": medication.id.uuidString,
				"displayName": medication.displayName,
				"quantity": medication.quantity ?? 0.0,
				"prescribedDoseAmount": medication.prescribedDoseAmount ?? 1.0,
				"prescribedUnit": medication.prescribedUnit?.rawValue ?? ANUnitConcept.dose.rawValue
			]
		}
		
		if session.isReachable {
			session.sendMessage(["medications": medicationData], replyHandler: nil) { error in
				print("ERROR: Error sending medications to watch \(error)")
			}
		}
	}
	
	private func handleDoseLogging(_ logDoseData: LogDoseData) async throws {
		guard let medicationId = UUID(uuidString: logDoseData.medicationId),
			  let doseUnit = ANUnitConcept(rawValue: logDoseData.doseUnit) else {
			print("WARNING: Invalid dose logging data from watch")
			return
		}
		
		// Find the medication
		guard let medication = DataStore.shared.medications.first(where: { $0.id == medicationId }) else {
			print("WARNING: Medication not found for dose logging")
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
		   let currentQuantity = medication.quantity {
			let updatedMedication = ANMedicationConcept(
				id: medication.id,
				clinicalName: medication.clinicalName,
				nickname: medication.nickname,
				quantity: max(0, currentQuantity - quantityConsumed),
				lastRefillDate: medication.lastRefillDate,
				nextRefillDate: medication.nextRefillDate,
				prescribedUnit: medication.prescribedUnit,
				prescribedDoseAmount: medication.prescribedDoseAmount
			)
			try await DataStore.shared.updateMedication(updatedMedication)
		}
		
		// Send confirmation back to watch
		if session.isReachable {
			session.sendMessage(["doseLogged": true], replyHandler: nil) { error in
				print("ERROR: Error sending dose confirmation to watch \(error)")
			}
		}
	}
	
	private func handleQuantityUpdate(_ quantityUpdateData: QuantityUpdateData) async throws {
		guard let medicationId = UUID(uuidString: quantityUpdateData.medicationId) else {
			print("WARNING: Invalid quantity update data from watch")
			return
		}
		
		// Find the medication
		guard let medication = DataStore.shared.medications.first(where: { $0.id == medicationId }) else {
			// Provide a lightweight, non-cryptographic hash for logging context
			let hashString = String(medicationId.uuidString.hashValue, radix: 16)
			print("WARNING: Medication not found for quantity update: medicationId=<hash:\(hashString)>")
			return
		}
		
		// Update medication quantity
		let updatedMedication = ANMedicationConcept(
			id: medication.id,
			clinicalName: medication.clinicalName,
			nickname: medication.nickname,
			quantity: quantityUpdateData.quantity,
			lastRefillDate: medication.lastRefillDate,
			nextRefillDate: medication.nextRefillDate,
			prescribedUnit: medication.prescribedUnit,
			prescribedDoseAmount: medication.prescribedDoseAmount
		)
		
		try await DataStore.shared.updateMedication(updatedMedication)
		
		// Send confirmation back to watch
		if session.isReachable {
			session.sendMessage(["quantityUpdated": true], replyHandler: nil) { error in
				print("ERROR: Error sending quantity update confirmation to watch \(error)")
			}
		}
	}
}

// MARK: - WCSessionDelegate

extension WCReceiver: WCSessionDelegate {
	nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
		Task { @MainActor in
			if let error = error {
				self.isConnected = false
				print("ERROR: WC Session activation failed \(error)")
			} else {
				self.isConnected = (activationState == .activated)
				print("INFO: WC Session activated: \(activationState)")
			}
		}
	}
	
	nonisolated func sessionDidBecomeInactive(_ session: WCSession) {
		Task { @MainActor in
			self.isConnected = false
		}
	}
	
	nonisolated func sessionDidDeactivate(_ session: WCSession) {
		Task { @MainActor in
			self.isConnected = false
		}
	}
	
	nonisolated func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
		handleMessage(message)
	}
	
	nonisolated func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
		handleMessage(message)
		replyHandler(["received": true])
	}
}
