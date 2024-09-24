//
//  DateAndArrayExtensions.swift
//  AsNeeded
//
//  Created by Dan Hart on 1/17/23.
//

import Foundation
import SwiftData

extension Date {
    func startOfDay(using calendar: Calendar = .current) -> Date {
        return calendar.startOfDay(for: self)
    }
}

extension Array where Element: LogItem {
    func groupedByDate() -> [Date: [Element]] {
        let calendar = Calendar.current
        return Dictionary(grouping: self, by: { $0.timestamp.startOfDay(using: calendar) })
    }
    
    func groupedByDate2DArray() -> [[Element]] {
        let calendar = Calendar.current
        var result: [[Element]] = []
        var currentGroup: [Element] = []
        var lastDate: Date?
        for log in self {
            let date = log.timestamp.startOfDay(using: calendar)
            if date != lastDate {
                if !currentGroup.isEmpty {
                    result.append(currentGroup)
                }
                currentGroup = []
                lastDate = date
            }
            currentGroup.append(log)
        }
        if !currentGroup.isEmpty {
            result.append(currentGroup)
        }
        return result
    }
}
