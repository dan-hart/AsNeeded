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
class Logbook: ObservableObject {
    static let shared = Logbook()
    
    init() {
    }
    
    lazy var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            LogItem.self,
            User.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    
    lazy var user: User = {
        if let user = getUser() {
            return user
        } else {
            fatalError("Could not fetch user")
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
        user.quantityInMG -= quantityInMG
        save()
    }
    
    func delete(log: LogItem) {
        user.quantityInMG += log.quantityInMG
        context.delete(log)
        save()
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
    func getUser() -> User? {
        do {
            return try context.fetch(FetchDescriptor<User>()).first
        } catch {
            print("Error fetching user: \(error)")
            return nil
        }
    }
    
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
