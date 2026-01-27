// QuickActionHandler.swift
// Handles app icon quick actions and widget deep links

import ANModelKit
import DHLoggingKit
import Foundation
import SwiftUI
import UIKit

/// Handles quick actions from app icon 3D touch and widget deep links
@MainActor
final class QuickActionHandler: ObservableObject {
    static let shared = QuickActionHandler()

    private let logger = DHLogger(category: "QuickActionHandler")
    private let navigationManager = NavigationManager.shared

    /// Published action that views can observe to handle navigation
    @Published var pendingAction: QuickAction?

    private init() {}

    // MARK: - Quick Action Types

    enum QuickAction: Equatable {
        case logDose(medicationID: UUID?)
        case viewHistory
        case addMedication
        case viewTrends
    }

    // MARK: - Handle App Icon Quick Actions

    /// Handle UIApplicationShortcutItem from app icon 3D touch
    func handleShortcutItem(_ shortcutItem: UIApplicationShortcutItem) {
        logger.info("Handling shortcut item: \(shortcutItem.type)")

        let action = parseShortcutItemType(shortcutItem.type)
        pendingAction = action
    }

    private func parseShortcutItemType(_ type: String) -> QuickAction {
        // Type format: "com.codedbydan.AsNeeded.quickaction.logdose"
        let components = type.components(separatedBy: ".")

        guard let actionType = components.last else {
            logger.warning("Invalid shortcut type: \(type)")
            return .viewHistory
        }

        switch actionType {
        case "logdose":
            return .logDose(medicationID: nil)
        case "history":
            return .viewHistory
        case "addmed":
            return .addMedication
        case "trends":
            return .viewTrends
        default:
            logger.warning("Unknown shortcut action: \(actionType)")
            return .viewHistory
        }
    }

    // MARK: - Handle Widget Deep Links

    /// Handle URL scheme from widgets or external sources
    /// Format: asneeded://log/<medicationID>
    /// Format: asneeded://history
    /// Format: asneeded://trends
    func handleURL(_ url: URL) {
        logger.info("Handling URL: \(url.absoluteString)")

        guard url.scheme == "asneeded" else {
            logger.warning("Invalid URL scheme: \(url.scheme ?? "nil")")
            return
        }

        let host = url.host
        let pathComponents = url.pathComponents.filter { $0 != "/" }

        switch host {
        case "log":
            // asneeded://log/<medicationID>
            if let medicationIDString = pathComponents.first,
               let medicationID = UUID(uuidString: medicationIDString)
            {
                logger.info("Deep link to log medication: \(medicationID)")
                pendingAction = .logDose(medicationID: medicationID)
            } else {
                // No specific medication, show medication list
                logger.info("Deep link to log dose (no specific medication)")
                pendingAction = .logDose(medicationID: nil)
            }

        case "history":
            logger.info("Deep link to history")
            pendingAction = .viewHistory

        case "trends":
            logger.info("Deep link to trends")
            pendingAction = .viewTrends

        case "add", "addmedication":
            logger.info("Deep link to add medication")
            pendingAction = .addMedication

        default:
            logger.warning("Unknown URL host: \(host ?? "nil")")
        }
    }

    // MARK: - Execute Actions

    /// Execute the pending action and clear it
    func executePendingAction() {
        guard let action = pendingAction else { return }

        logger.info("Executing pending action")

        switch action {
        case let .logDose(medicationID):
            handleLogDoseAction(medicationID: medicationID)

        case .viewHistory:
            handleViewHistoryAction()

        case .addMedication:
            handleAddMedicationAction()

        case .viewTrends:
            handleViewTrendsAction()
        }

        // Clear pending action after execution
        pendingAction = nil
    }

    private func handleLogDoseAction(medicationID: UUID?) {
        if let medicationID = medicationID {
            // Navigate to log dose for specific medication
            // This will be handled by the UI layer setting up state
            logger.info("Navigate to log dose for medication: \(medicationID)")
        } else {
            // Navigate to medication list (default tab)
            logger.info("Navigate to medication list")
        }
        // The actual navigation is handled by the ContentView observing pendingAction
    }

    private func handleViewHistoryAction() {
        // Switch to history tab
        navigationManager.selectedTab = 1
        logger.info("Switched to history tab")
    }

    private func handleAddMedicationAction() {
        // Navigate to medication list tab and trigger add sheet
        // This will be handled by the UI layer
        logger.info("Navigate to add medication")
    }

    private func handleViewTrendsAction() {
        // Switch to trends tab
        navigationManager.selectedTab = 2
        logger.info("Switched to trends tab")
    }

    // MARK: - Public Helper

    /// Clear any pending action
    func clearPendingAction() {
        pendingAction = nil
    }
}

// MARK: - ContentView Extension

extension View {
    /// Handle quick actions in the view
    func onQuickAction(perform action: @escaping (QuickActionHandler.QuickAction) -> Void) -> some View {
        onReceive(QuickActionHandler.shared.$pendingAction) { quickAction in
            if let quickAction = quickAction {
                action(quickAction)
            }
        }
    }
}
