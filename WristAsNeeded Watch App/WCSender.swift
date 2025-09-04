//
//  WCSender.swift
//  WristAsNeeded Watch App
//
//  Created by AsNeeded Team on 9/24/24.
//

import WatchConnectivity

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
		guard session.isReachable else {
			print("Session is not reachable")
			return
		}
		
		let messages: [String: Any] = [key: value]
		session.sendMessage(messages, replyHandler: nil) { (error) in
			print("Error sending message: \(error)")
		}
	}
	
	private func handleMessage(_ message: [String: Any]) {
		DispatchQueue.main.async {
			if let medicationsData = message["medications"] as? [[String: Any]] {
				self.medications = medicationsData.map { WatchMedication(from: $0) }
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
}
