// CheckRefillStatusIntent.swift
// App Intent for checking which medications need refills

import ANModelKit
import AppIntents
import DHLoggingKit
import Foundation
import SwiftUI

@available(iOS 16.0, *)
struct CheckRefillStatusIntent: AppIntent {
    static let title: LocalizedStringResource = "Check Refill Status"
    static let description = IntentDescription("Check which medications need refills soon")
    static let openAppWhenRun: Bool = false

    private let logger = DHLogger(category: "CheckRefillStatusIntent")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        logger.info("Performing CheckRefillStatusIntent")

        let medications = DataStore.shared.medications

        guard !medications.isEmpty else {
            logger.info("No medications found")
            return .result(
                dialog: IntentDialog("You don't have any medications added to AsNeeded yet."),
                view: EmptyRefillView()
            )
        }

        // Find medications that need refills
        var needsRefill: [RefillInfo] = []
        var lowQuantity: [RefillInfo] = []

        for medication in medications {
            // Check refill date
            if let refillDate = medication.nextRefillDate {
                let daysUntil = Calendar.current.dateComponents(
                    [.day],
                    from: Date(),
                    to: refillDate
                ).day ?? 0

                if daysUntil <= 7 && daysUntil >= 0 {
                    needsRefill.append(RefillInfo(
                        name: medication.displayName,
                        daysUntil: daysUntil,
                        quantity: medication.quantity
                    ))
                }
            }

            // Check low quantity (< 10)
            if let quantity = medication.quantity, quantity < 10 {
                // Only add if not already in refill list
                if !needsRefill.contains(where: { $0.name == medication.displayName }) {
                    lowQuantity.append(RefillInfo(
                        name: medication.displayName,
                        daysUntil: nil,
                        quantity: quantity
                    ))
                }
            }
        }

        // Build response
        if needsRefill.isEmpty && lowQuantity.isEmpty {
            logger.info("No medications need refills")
            return .result(
                dialog: IntentDialog("All your medications are well stocked. No refills needed right now."),
                view: AllGoodRefillView()
            )
        }

        var dialogParts: [String] = []

        if !needsRefill.isEmpty {
            let names = needsRefill.map { $0.name }.joined(separator: ", ")
            dialogParts.append("\(needsRefill.count) medication\(needsRefill.count == 1 ? "" : "s") need refills soon: \(names)")
        }

        if !lowQuantity.isEmpty {
            let names = lowQuantity.map { $0.name }.joined(separator: ", ")
            dialogParts.append("\(lowQuantity.count) medication\(lowQuantity.count == 1 ? " is" : "s are") running low: \(names)")
        }

        let dialog = dialogParts.joined(separator: ". ")

        logger.info("Refill status: \(needsRefill.count) need refills, \(lowQuantity.count) low quantity")

        return .result(
            dialog: IntentDialog(stringLiteral: dialog),
            view: RefillStatusView(needsRefill: needsRefill, lowQuantity: lowQuantity)
        )
    }
}

// MARK: - Supporting Types

struct RefillInfo: Identifiable {
    let id = UUID()
    let name: String
    let daysUntil: Int?
    let quantity: Double?
}

// MARK: - Snippet Views

struct RefillStatusView: View {
    let needsRefill: [RefillInfo]
    let lowQuantity: [RefillInfo]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "calendar.badge.exclamationmark")
                    .font(.title2)
                    .foregroundStyle(.accent)

                Text("Refill Status")
                    .font(.headline)
            }

            if !needsRefill.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "calendar")
                            .font(.caption)
                            .foregroundStyle(.orange)

                        Text("Refills Due Soon")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.orange)
                    }

                    ForEach(needsRefill) { info in
                        HStack {
                            Text("• \(info.name)")
                                .font(.caption)

                            Spacer()

                            if let days = info.daysUntil {
                                Text("\(days)d")
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            if !lowQuantity.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.red)

                        Text("Low Quantity")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.red)
                    }

                    ForEach(lowQuantity) { info in
                        HStack {
                            Text("• \(info.name)")
                                .font(.caption)

                            Spacer()

                            if let qty = info.quantity {
                                Text("\(qty.formattedAmount)")
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .padding()
    }
}

struct AllGoodRefillView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.largeTitle)
                .foregroundStyle(.green)

            Text("All Medications Stocked")
                .font(.headline)
                .foregroundStyle(.primary)

            Text("No refills needed")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

struct EmptyRefillView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "pills")
                .font(.largeTitle)
                .foregroundStyle(.secondary)

            Text("No Medications")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}
