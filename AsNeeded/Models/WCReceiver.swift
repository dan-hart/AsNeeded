//
//  WCReceiver.swift
//  AsNeeded
//
//  Created by Dan Hart on 9/24/24.
//

import SwiftUI
import WatchConnectivity

final class WCReceiver: NSObject, ObservableObject {
    @Published var messages: [String] = []
    
    var session: WCSession
    var onMessageReceived: (([String: Any]) -> Void)?
    
    init(session: WCSession = .default) {
        self.session = session
        super.init()
        self.session.delegate = self
        session.activate()
    }
}

extension WCReceiver: WCSessionDelegate {
    func sessionDidBecomeInactive(_ session: WCSession) {
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
    }
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            print(error.localizedDescription)
        } else {
            print("The session has completed activation.")
        }
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        DispatchQueue.main.async {
            self.onMessageReceived?(message)
        }
    }
}
