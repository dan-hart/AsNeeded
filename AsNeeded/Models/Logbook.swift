//
//  Logbook.swift
//  AsNeeded
//
//  Created by Dan Hart on 1/17/23.
//

import Foundation
import UIKit
import SwiftData

@MainActor
class Logbook {
    static let shared = Logbook()
    
    lazy var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            LogItem.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    
    var context: ModelContext {
        sharedModelContainer.mainContext
    }
    
    /// Log one now
    func quickLog() {
        log(quantityInMG: 1, at: .now)
    }
    
    func log(quantityInMG: Double, at: Date) {
        let log = LogItem(timestamp: at, quantityInMG: quantityInMG)
        context.insert(log)
    }
    
    func delete(log: LogItem) {
        UserData.shared.quantityInMG += log.quantityInMG
        context.delete(log)
    }
    
    func save() {
        do {
            if self.context.hasChanges {
                try self.context.save()
            }
        } catch {
            print("Error saving log: \(error)")
        }
    }
    
    // MARK: - Querying
    func getLogs() -> [LogItem] {
        do {
            return try context.fetch(FetchDescriptor<LogItem>())
        } catch {
            print("Error fetching logs: \(error)")
            return []
        }
    }
    
    func getLogs(for date: Date) -> [LogItem]? {
        let logs = getLogs().filter { item in
            item.timestamp.startOfDay() == date.startOfDay()
        }
        return logs
    }
}
