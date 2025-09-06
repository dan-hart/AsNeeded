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
			session.sendMessage(messages, replyHandler: nil) { (error) in
				print("Error sending message: \(error)")
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
			}
			
			// Handle confirmations from iPhone
			if let doseLogged = message["doseLogged"] as? Bool, doseLogged {
				// Dose was successfully logged
				WKInterfaceDevice.current().play(.notification)
			}
			
			if let quantityUpdated = message["quantityUpdated"] as? Bool, quantityUpdated {
				// Quantity was successfully updated
				print("Quantity updated successfully")
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
	
	func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
		handleMessage(message)
	}
	
	func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
		handleMessage(message)
		replyHandler(["received": true])
	}
	
	func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any]) {
		handleMessage(userInfo)
	}
	
	func sessionReachabilityDidChange(_ session: WCSession) {
		DispatchQueue.main.async {
			self.isConnected = session.isReachable
			print("Session reachability changed: \(session.isReachable)")
		}
	}
}
