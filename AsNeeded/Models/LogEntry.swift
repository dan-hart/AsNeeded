//
//  LogEntry.swift
//  AsNeeded
//
//  Created by Dan Hart on 1/17/23.
//

import Foundation
import RealmSwift

class LogEntry: Object {
    @Persisted(primaryKey: true) var _id: String
    
    @Persisted var timestamp: Date
    @Persisted var quantityInMG: Double

    var roundedQuantityInMG: String {
        "\(quantityInMG.rounded(toPlaces: 1))"
    }
}

extension LogEntry: Identifiable { }

extension LogEntry {
    static func preview() -> LogEntry {
        let log = LogEntry()
        log.timestamp = .now
        log.quantityInMG = 2.0
        return log
    }
}

extension Date {
    func startOfDay(using calendar: Calendar = .current) -> Date {
        return calendar.startOfDay(for: self)
    }
}

extension Array where Element: LogEntry {
    func groupedByDate() -> [Date: [Element]] {
        let calendar = Calendar.current
        return Dictionary(grouping: self, by: { $0.timestamp.startOfDay(using: calendar) })
    }
}
