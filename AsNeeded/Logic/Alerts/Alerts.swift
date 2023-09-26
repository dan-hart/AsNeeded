//
//  Alerts.swift
//
//  Created by Dan Hart on 6/4/20.
//  Copyright © 2020 Dan Hart. All rights reserved.
//

import Foundation
import UserNotifications
import UIKit

enum AlertsError: Error {
case notificationsNotAllowed
}

/// Use this class to coordinate alerts
class Alerts: ObservableObject {
    /// Use a singleton to provide consistent access
    static let shared = Alerts()
    
    // MARK: - Properties
    @Published var status: UNAuthorizationStatus
    @Published var areAllowed: Bool
    
    /// The current notification center
    let center = UNUserNotificationCenter.current()
    
    init() {
        self.status = .notDetermined
        self.areAllowed = false
        
        self.refresh()
    }
    
    // MARK: - Methods
    func refresh() {
        center.getNotificationSettings { (settings) in
            self.status = settings.authorizationStatus
            switch self.status {
            case .authorized:
                self.areAllowed = true
            default:
                self.areAllowed = false
            }
        }
    }
    
    /// Asks the user if they would like to receive notifications
    /// - Parameter didUpdateAllowedTo: called when the status is updated
    func requestAuthorization(didUpdateAllowedTo: @escaping (Bool) -> Void) {
        center.requestAuthorization(options: [.alert, .badge, .sound]) { success, error in
            if success {
                self.status = .authorized
            } else if let error = error {
                print(error)
                self.status = .denied
            }
            
            switch self.status {
            case .authorized:
                self.areAllowed = true
            default:
                self.areAllowed = false
            }
            
            didUpdateAllowedTo(self.areAllowed)
        }
    }
    
    /// Set the Application's Badge
    /// - Parameter count: To this count
    func setBadgeTo(count: Int) {
        UNUserNotificationCenter.current().setBadgeCount(count)
    }
    
    /// Create a notification at the specified date
    /// - Parameters:
    ///   - withTitle: The title of the notification
    ///   - body: The body of the notification
    ///   - date: the date the notification will fire
    ///   - completion: Called with the (identifier, error)
    func create(withTitle: String, body: String, at date: Date, identifiedBy: String, completion: @escaping (Swift.Result<String, Error>) -> Void) {
        if !self.areAllowed {
            self.requestAuthorization { isAllowed in
                if isAllowed {
                    let content = self.content(title: withTitle, body: body)
                    let trigger = self.trigger(from: date)
                    self.schedule(content: content, trigger: trigger, withIdentifier: identifiedBy, completion: completion)
                } else {
                    completion(.failure(AlertsError.notificationsNotAllowed))
                }
            }
        } else {
            let content = self.content(title: withTitle, body: body)
            let trigger = self.trigger(from: date)
            self.schedule(content: content, trigger: trigger, withIdentifier: identifiedBy, completion: completion)
        }
    }
    
    /// Get pending notifications using the given identifier
    /// - Parameters:
    ///   - identifier: how the notification is identified
    ///   - completion: given an optional `UNNotificationRequest` found from the given identifier.
    func get(with identifier: String, completion: @escaping (UNNotificationRequest?) -> Void) {
        center.getPendingNotificationRequests { (requests) in
            for request in requests where request.identifier == identifier {
                completion(request)
            }
            
            completion(nil)
        }
    }
    
    /// Remove a pending notification matching the given identifier
    /// - Parameter withIdentifier: how the notification is identified
    func removePending(withIdentifier: String) {
        self.removePending(withIdentifiers: [withIdentifier])
    }
    
    /// Remove all of the pending notifications with these identifiers
    /// - Parameter withIdentifiers: identifiers
    func removePending(withIdentifiers: [String]) {
        center.removePendingNotificationRequests(withIdentifiers: withIdentifiers)
    }
    
    func removeDelivered(withIdentifier: String) {
        self.removeDelivered(withIdentifiers: [withIdentifier])
    }
    
    func removeDelivered(withIdentifiers: [String]) {
        center.removeDeliveredNotifications(withIdentifiers: withIdentifiers)
    }
    
    /// Create notification content with these values
    /// - Parameters:
    ///   - title: the title of the notification
    ///   - body: the body of the notification
    /// - Returns: the content object
    func content(title: String, body: String) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = UNNotificationSound.default
        return content
    }
    
    /// Create a one-time trigger from the given date
    /// - Parameters:
    ///   - date: the date/time the trigger should be set at
    /// - Returns: the notification tigger object
    func trigger(from date: Date) -> UNCalendarNotificationTrigger {
        let triggerDate = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        return UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)
    }
    
    /// Using the given parameters, schedule the notification
    /// - Parameters:
    ///   - content: the content of the notification
    ///   - trigger: the notification trigger
    ///   - completion: called when `add` is complete
    func schedule(content: UNMutableNotificationContent, trigger: UNCalendarNotificationTrigger, withIdentifier: String, completion: @escaping (Swift.Result<String, Error>) -> Void) {
        let request = UNNotificationRequest(identifier: withIdentifier, content: content, trigger: trigger)

        center.add(request, withCompletionHandler: { (error) in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(withIdentifier))
            }
        })
    }
}
