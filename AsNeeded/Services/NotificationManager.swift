// NotificationManager.swift
// Centralized notification handling for medication reminders

import Foundation
import UserNotifications
import ANModelKit
import DHLoggingKit

@MainActor
final class NotificationManager: ObservableObject {
  static let shared = NotificationManager()
  private let logger = DHLogger(category: "NotificationManager")
  
  enum AuthorizationStatus {
    case notDetermined
    case denied
    case authorized
    case provisional
    case ephemeral
    case unknown
  }
  
  @Published var authorizationStatus: AuthorizationStatus = .notDetermined
  @Published var showMedicationNames: Bool = false {
    didSet {
      UserDefaults.standard.set(showMedicationNames, forKey: UserDefaultsKeys.showMedicationNamesInNotifications)
    }
  }

  private let notificationCenter = UNUserNotificationCenter.current()

  private init() {
    showMedicationNames = UserDefaults.standard.object(forKey: UserDefaultsKeys.showMedicationNamesInNotifications) as? Bool ?? false
    Task {
      await checkAuthorizationStatus()
      await setupNotificationCategories()
    }
  }
  
  private func setupNotificationCategories() async {
    let takenAction = UNNotificationAction(
      identifier: "TAKEN_ACTION",
      title: "Mark as Taken",
      options: [.foreground]
    )
    
    let skipAction = UNNotificationAction(
      identifier: "SKIP_ACTION", 
      title: "Skip",
      options: []
    )
    
    let medicationCategory = UNNotificationCategory(
      identifier: "MEDICATION_REMINDER",
      actions: [takenAction, skipAction],
      intentIdentifiers: [],
      hiddenPreviewsBodyPlaceholder: "Medication reminder",
      options: []
    )
    
    notificationCenter.setNotificationCategories([medicationCategory])
    logger.debug("Notification categories configured")
  }
  
  func checkAuthorizationStatus() async {
    let settings = await notificationCenter.notificationSettings()
    await MainActor.run {
      switch settings.authorizationStatus {
      case .notDetermined:
        self.authorizationStatus = .notDetermined
      case .denied:
        self.authorizationStatus = .denied
      case .authorized:
        self.authorizationStatus = .authorized
      case .provisional:
        self.authorizationStatus = .provisional
      case .ephemeral:
        self.authorizationStatus = .ephemeral
      @unknown default:
        self.authorizationStatus = .unknown
      }
    }
    logger.debug("Notification authorization status: \(String(describing: authorizationStatus))")
  }
  
  func requestAuthorization() async -> Bool {
    do {
      let granted = try await notificationCenter.requestAuthorization(options: [.alert, .badge, .sound])
      await checkAuthorizationStatus()
      logger.info("Notification authorization requested - granted: \(granted)")
      return granted
    } catch {
      logger.error("Failed to request notification authorization", error: error)
      return false
    }
  }
  
  func scheduleReminder(
    for medication: ANMedicationConcept,
    date: Date,
    isRecurring: Bool,
    repeatInterval: DateComponents? = nil
  ) async throws {
    logger.info("Scheduling reminder for medication: \(medication.id)")
    
    // Create notification content
    let content = UNMutableNotificationContent()
    
    if showMedicationNames {
      content.title = medication.displayName
      content.body = "It's time to take \(medication.displayName)"
    } else {
      content.title = "Medication Reminder"
      content.body = "It's time to take your medication"
    }
    
    content.sound = .default
    content.categoryIdentifier = "MEDICATION_REMINDER"
    content.userInfo = ["medicationId": medication.id.uuidString]
    
    // Create trigger
    let trigger: UNNotificationTrigger
    if isRecurring, let repeatInterval = repeatInterval {
      trigger = UNCalendarNotificationTrigger(dateMatching: repeatInterval, repeats: true)
    } else {
      let dateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
      trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
    }
    
    // Create request
    let requestId = "\(medication.id.uuidString)-\(date.timeIntervalSince1970)"
    let request = UNNotificationRequest(identifier: requestId, content: content, trigger: trigger)
    
    // Schedule notification
    try await notificationCenter.add(request)
    logger.info("Reminder scheduled successfully with ID: \(requestId)")
  }
  
  func cancelReminder(for medication: ANMedicationConcept) async {
    logger.info("Cancelling reminders for medication: \(medication.id)")
    
    let pendingRequests = await notificationCenter.pendingNotificationRequests()
    let requestsToCancel = pendingRequests
      .filter { $0.identifier.contains(medication.id.uuidString) }
      .map { $0.identifier }
    
    if !requestsToCancel.isEmpty {
      notificationCenter.removePendingNotificationRequests(withIdentifiers: requestsToCancel)
      logger.info("Cancelled \(requestsToCancel.count) reminders")
    }
  }
  
  func getPendingReminders(for medication: ANMedicationConcept) async -> [UNNotificationRequest] {
    let pendingRequests = await notificationCenter.pendingNotificationRequests()
    return pendingRequests.filter { $0.identifier.contains(medication.id.uuidString) }
  }
  
  func getReminderDetails(for medication: ANMedicationConcept) async -> [ReminderDetail] {
    let pendingRequests = await getPendingReminders(for: medication)
    return pendingRequests.compactMap { request in
      ReminderDetail(from: request)
    }.sorted { $0.nextFireDate < $1.nextFireDate }
  }
  
  func cancelSpecificReminder(withIdentifier identifier: String) async {
    notificationCenter.removePendingNotificationRequests(withIdentifiers: [identifier])
    logger.info("Cancelled specific reminder: \(identifier)")
  }
  
  func cancelAllReminders() async {
    notificationCenter.removeAllPendingNotificationRequests()
    logger.info("All reminders cancelled")
  }
}

struct ReminderDetail: Identifiable {
  let id: String
  let nextFireDate: Date
  let title: String
  let body: String
  let isRepeating: Bool
  let repeatInfo: String?
  
  init?(from request: UNNotificationRequest) {
    guard let trigger = request.trigger else { return nil }
    
    self.id = request.identifier
    self.title = request.content.title
    self.body = request.content.body
    
    if let calendarTrigger = trigger as? UNCalendarNotificationTrigger {
      self.isRepeating = calendarTrigger.repeats
      
      // Calculate next fire date
      if let nextFireDate = calendarTrigger.nextTriggerDate() {
        self.nextFireDate = nextFireDate
      } else {
        self.nextFireDate = Date()
      }
      
      // Generate repeat info
      if calendarTrigger.repeats {
        let components = calendarTrigger.dateComponents
        if let weekday = components.weekday, let hour = components.hour, let minute = components.minute {
          let weekdayName = Calendar.current.weekdaySymbols[weekday - 1]
          self.repeatInfo = "Weekly on \(weekdayName) at \(String(format: "%02d:%02d", hour, minute))"
        } else if let hour = components.hour, let minute = components.minute {
          self.repeatInfo = "Daily at \(String(format: "%02d:%02d", hour, minute))"
        } else {
          self.repeatInfo = "Recurring"
        }
      } else {
        self.repeatInfo = nil
      }
    } else {
      self.nextFireDate = Date()
      self.isRepeating = false
      self.repeatInfo = nil
    }
  }
}