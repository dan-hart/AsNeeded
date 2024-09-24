//
//  AnimalListViewModel.swift
//  AsNeeded
//
//  Created by Dan Hart on 9/24/24.
//

import WatchConnectivity

final class WCSender: NSObject, ObservableObject {
    var session: WCSession
    
    @Published var isConnected = false
    
    init(session: WCSession  = .default) {
        self.session = session
        super.init()
        self.session.delegate = self
        session.activate()
    }
    
    func sendMessage(key: String, value: Any) {
         let messages: [String: Any] = [key: value]
         session.sendMessage(messages, replyHandler: nil) { (error) in
             print(error.localizedDescription)
         }
     }
}

extension WCSender: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            isConnected = false
            print(error.localizedDescription)
        } else {
            isConnected = true
        }
    }
}
