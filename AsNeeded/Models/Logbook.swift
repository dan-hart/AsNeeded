//
//  Logbook.swift
//  AsNeeded
//
//  Created by Dan Hart on 1/17/23.
//

import Foundation
import RealmSwift
import UIKit

class Logbook {
    static let realm = try? Realm()
    
    /// Log one now
    static func quickLog() {
        log(quantityInMG: 1, at: .now)
    }
    
    static func log(quantityInMG: Double, at: Date) {
        let log = LogEntry()
        log._id = UUID().uuidString
        log.timestamp = at
        log.quantityInMG = quantityInMG
        
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()

        try? realm?.write {
            realm?.add(log)
        }
    }
}
