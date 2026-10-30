//
//  WCSender.swift
//  WristAsNeeded Watch App
//
//  Created by Dan Hart on 9/24/24.
//

import WatchConnectivity
import WatchKit

final class WCSender: NSObject, ObservableObject {
    var session: WCSession

    @Published var isConnected = false
    @Published var medications: [WatchMedication] = []
	@Published var hasLoadedMedications = false
	@Published var loadErrorMessage: String?
	@Published var actionMessage: String?
	@Published var isSendingAction = false

	enum ActionOutcome {
		case saved
		case queued
		case failed
	}

	/// A queued transfer is not a saved dose. Only the phone's persistence reply confirms saving.
	@MainActor
	func sendAction(key: String, value: Any) async -> ActionOutcome {
		guard !isSendingAction else { return .failed }
		guard session.activationState == .activated else {
			actionMessage = String(localized: "iPhone connection is starting. Try again shortly.")
			return .failed
		}
		var payload = value
		if key == "logDose", var dose = value as? [String: Any] {
			if dose["eventID"] == nil { dose["eventID"] = UUID().uuidString }
			if dose["date"] == nil { dose["date"] = Date() }
			payload = dose
		}
		let message = [key: payload]
		guard session.isReachable else {
			session.transferUserInfo(message)
			actionMessage = key == "logDose"
				? String(localized: "Waiting to sync with iPhone. Don’t log this dose again.")
				: String(localized: "Quantity is waiting to sync with iPhone.")
			return .queued
		}
		isSendingAction = true
		actionMessage = String(localized: "Saving on iPhone…")
		let saved: Bool = await withCheckedContinuation { continuation in
			session.sendMessage(message, replyHandler: { reply in
				continuation.resume(returning: reply["saved"] as? Bool == true)
			}, errorHandler: { _ in
				continuation.resume(returning: false)
			})
		}
		isSendingAction = false
		actionMessage = saved ? String(localized: "Saved on iPhone.") : String(localized: "Couldn’t confirm saving. Check iPhone before trying again.")
		return saved ? .saved : .failed
	}

    init(session: WCSession = .default) {
        self.session = session
        super.init()
        if WCSession.isSupported() {
            self.session.delegate = self
            session.activate()
        }
    }

    func sendMessage(key: String, value: Any) {
        // Try to send message even if not immediately reachable
        // The system will queue it and send when possible
        let messages: [String: Any] = [key: value]

        if session.isReachable {
            session.sendMessage(messages, replyHandler: nil) { error in
                print("Error sending message: \(error)")
				DispatchQueue.main.async {
					self.loadErrorMessage = String(localized: "Couldn’t load medications. Open AsNeeded on iPhone, then refresh.")
				}
            }
        } else {
            // Try to transfer user info when not reachable
            // This will be queued and delivered when the phone app opens
            session.transferUserInfo(messages)
            print("Session not reachable, queued message for later delivery")
        }
    }

    private func handleMessage(_ message: [String: Any]) {
        DispatchQueue.main.async {
            if let medicationsData = message["medications"] as? [[String: Any]] {
                self.medications = medicationsData.map { WatchMedication(from: $0) }
				self.hasLoadedMedications = true
				self.loadErrorMessage = nil
            }

            // Handle confirmations from iPhone
            if let doseLogged = message["doseLogged"] as? Bool, doseLogged {
                // Dose was successfully logged
                WKInterfaceDevice.current().play(.notification)
				self.actionMessage = String(localized: "Dose saved on iPhone.")
            }

            if let quantityUpdated = message["quantityUpdated"] as? Bool, quantityUpdated {
                // Quantity was successfully updated
                print("Quantity updated successfully")
				self.actionMessage = String(localized: "Quantity saved on iPhone.")
            }
			if message["saveFailed"] as? Bool == true {
				self.actionMessage = String(localized: "Couldn’t confirm saving. Check iPhone before trying again.")
			}
        }
    }
}

extension WCSender: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            if let error = error {
                self.isConnected = false
                print("WC Session activation failed: \(error)")
            } else {
                self.isConnected = (activationState == .activated && session.isReachable)
                print("WC Session activated: \(activationState), reachable: \(session.isReachable)")
            }
        }
    }

    func session(_: WCSession, didReceiveMessage message: [String: Any]) {
        handleMessage(message)
    }

    func session(_: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        handleMessage(message)
        replyHandler(["received": true])
    }

    func session(_: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        handleMessage(userInfo)
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isConnected = session.isReachable
            print("Session reachability changed: \(session.isReachable)")
        }
    }
}
