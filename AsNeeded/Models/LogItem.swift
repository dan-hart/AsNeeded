//
//  LogItem.swift
//  AsNeeded
//
//  Created by Dan Hart on 9/23/24.
//

import Foundation
import SwiftData
#if os(iOS)
import SwiftDate
#endif

@Model
class LogItem: Identifiable, Hashable, Equatable {
    var id: String = UUID().uuidString
    var timestamp: Date = Date()
    var quantityInMG: Double = 0

    var roundedQuantityInMG: String {
        let result = "\(quantityInMG.rounded(toPlaces: 1))"
        if result.hasSuffix(".0") {
            return String(result.dropLast(2))
        } else {
            return result
        }
    }
    
    convenience init() {
        self.init(timestamp: Date(), quantityInMG: 0)
    }
    
    init(timestamp: Date, quantityInMG: Double) {
        self.timestamp = timestamp
        self.quantityInMG = quantityInMG
    }
    
    static func == (lhs: LogItem, rhs: LogItem) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    #if DEBUG
    static func preview() -> LogItem {
        LogItem(timestamp: Date(), quantityInMG: 1)
    }
    #endif
}

extension LogItem {    
    static func last30DaysPredicate() -> Predicate<LogItem> {
        let days30Ago = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        
        return #Predicate<LogItem> { item in
            item.timestamp >= days30Ago
        }
    }

    static func pastPredicate() -> Predicate<LogItem> {
        let currentDate = Date.now

        return #Predicate<LogItem> { item in
            item.timestamp < currentDate
        }
    }
}
