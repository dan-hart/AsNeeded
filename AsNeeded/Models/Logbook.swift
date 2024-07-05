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

        try? realm?.write {
            realm?.add(log)
        }
    }
    
    static func delete(log: LogEntry) {
        try? realm?.write {
            realm?.delete(log)
        }
    }
    
    // MARK: - Querying
    static func getLogs() -> Results<LogEntry>? {
        realm?.objects(LogEntry.self)
    }
    
    static func getLogs(for date: Date) -> [LogEntry]? {
        let startOfDay = date.startOfDay()
        let endOfDay = startOfDay.addingTimeInterval(60 * 60 * 24)
        
        guard let results = realm?.objects(LogEntry.self).filter("timestamp >= %@ AND timestamp < %@", startOfDay, endOfDay) else { return nil }
        return results.map({$0})
    }
}
