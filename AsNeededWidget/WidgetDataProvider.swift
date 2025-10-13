// WidgetDataProvider.swift
// Data provider for widget using App Group shared storage

import Foundation
import ANModelKit
import Boutique
import WidgetKit

/// Provides medication data to widgets via App Group shared storage
@MainActor
final class WidgetDataProvider {
	static let shared = WidgetDataProvider()

	// App Group identifier matching main app
	let appGroupIdentifier = "group.com.codedbydan.AsNeeded"

	// Boutique stores using shared App Group container - made internal for widget intent access
	let medicationsStore: Store<ANMedicationConcept>
	let eventsStore: Store<ANEventConcept>

	init() {
		// Get shared container URL for App Group
		guard let sharedContainerURL = FileManager.default.containerURL(
			forSecurityApplicationGroupIdentifier: appGroupIdentifier
		) else {
			fatalError("Unable to access App Group container")
		}

		// Initialize stores with shared container path using FileManager.Directory
		self.medicationsStore = Store<ANMedicationConcept>(
			storage: SQLiteStorageEngine(
				directory: FileManager.Directory(url: sharedContainerURL),
				databaseFilename: "medications"
			)!,
			cacheIdentifier: \ANMedicationConcept.id.uuidString
		)

		self.eventsStore = Store<ANEventConcept>(
			storage: SQLiteStorageEngine(
				directory: FileManager.Directory(url: sharedContainerURL),
				databaseFilename: "events"
			)!,
			cacheIdentifier: \ANEventConcept.id.uuidString
		)
	}

	// MARK: - Public Interface

	/// Get all active medications
	var medications: [ANMedicationConcept] {
		medicationsStore.items.filter { !$0.isArchived }
	}

	/// Get all events
	var events: [ANEventConcept] {
		eventsStore.items
	}

	/// Get medications sorted by display name
	var medicationsByNextDose: [ANMedicationConcept] {
		medications.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
	}

	/// Get the next medication due to be taken
	var nextMedicationDue: ANMedicationConcept? {
		medicationsByNextDose.first
	}

	/// Calculate next dose time for a medication (simplified - just shows if taken recently)
	func nextDoseTime(for medication: ANMedicationConcept) -> Date? {
		// Get most recent event for this medication
		let medicationEvents = events
			.filter { $0.medication?.id == medication.id }
			.sorted { $0.date > $1.date }

		guard let lastEvent = medicationEvents.first else {
			// No history, can take now
			return Date()
		}

		// For simplicity, show as available after 4 hours
		return lastEvent.date.addingTimeInterval(4 * 3600)
	}

	/// Check if medication can be taken now
	func canTakeNow(_ medication: ANMedicationConcept) -> Bool {
		guard let nextTime = nextDoseTime(for: medication) else {
			return true
		}
		return nextTime <= Date()
	}

	/// Get time remaining until next dose
	func timeUntilNextDose(for medication: ANMedicationConcept) -> TimeInterval? {
		guard let nextTime = nextDoseTime(for: medication) else {
			return nil
		}

		let interval = nextTime.timeIntervalSince(Date())
		return max(0, interval)
	}

	/// Get medications that are low on quantity (< 10)
	var lowQuantityMedications: [ANMedicationConcept] {
		medications.filter { medication in
			if let quantity = medication.quantity {
				return quantity < 10
			}
			return false
		}
	}

	/// Get medications that need refill soon (within 7 days)
	var refillDueSoon: [ANMedicationConcept] {
		medications.filter { medication in
			guard let refillDate = medication.nextRefillDate else {
				return false
			}

			let daysUntilRefill = Calendar.current.dateComponents(
				[.day],
				from: Date(),
				to: refillDate
			).day ?? 0

			return daysUntilRefill <= 7 && daysUntilRefill >= 0
		}
	}
}

// MARK: - Helper Extensions

extension ANMedicationConcept {
	var displayName: String {
		if let nickname = nickname, !nickname.isEmpty {
			return nickname
		}
		return clinicalName
	}

	/// Returns the display color for this medication, falling back to blue if none set
	var displayColor: Color {
		if let hexColor = displayColorHex {
			return Color(hex: hexColor) ?? .blue
		}
		return .blue
	}

	// Default symbol based on medication unit type
	var defaultSymbol: String {
		if let unit = prescribedUnit {
			switch unit {
			case .puff:
				return "wind"
			case .drop:
				return "drop.fill"
			case .spray:
				return "humidity"
			case .injection:
				return "syringe.fill"
			case .patch:
				return "bandage.fill"
			case .lozenge:
				return "circle.fill"
			case .suppository:
				return "capsule.fill"
			case .tablet:
				return "pills.fill"
			case .capsule:
				return "capsule.portrait.fill"
			default:
				return "pills.fill"
			}
		}
		return "pills.fill"
	}

	// Display symbol with fallback to default
	var effectiveDisplaySymbol: String {
		symbolInfo?.name ?? defaultSymbol
	}
}

// MARK: - Color Hex Extension

import SwiftUI

extension Color {
	init?(hex: String) {
		let hexString = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
		var int: UInt64 = 0
		Scanner(string: hexString).scanHexInt64(&int)
		let a, r, g, b: UInt64
		switch hexString.count {
		case 3: // RGB (12-bit)
			(a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
		case 6: // RGB (24-bit)
			(a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
		case 8: // ARGB (32-bit)
			(a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
		default:
			return nil
		}
		self.init(
			.sRGB,
			red: Double(r) / 255,
			green: Double(g) / 255,
			blue: Double(b) / 255,
			opacity: Double(a) / 255
		)
	}
}
