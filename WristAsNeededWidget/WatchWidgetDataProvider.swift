// WatchWidgetDataProvider.swift
// Data provider for watch complications using App Group shared storage

import ANModelKit
import Boutique
import Foundation
import WidgetKit

/// Provides medication data to watch complications via App Group shared storage
@MainActor
final class WatchWidgetDataProvider {
	static let shared = WatchWidgetDataProvider()

	// App Group identifier matching main app
	let appGroupIdentifier = "group.com.codedbydan.AsNeeded"

	// Boutique stores using shared App Group container
	let medicationsStore: Store<ANMedicationConcept>
	let eventsStore: Store<ANEventConcept>

	init() {
		// Get shared container URL for App Group
		guard let sharedContainerURL = FileManager.default.containerURL(
			forSecurityApplicationGroupIdentifier: appGroupIdentifier
		),
			let medicationsEngine = SQLiteStorageEngine(
				directory: FileManager.Directory(url: sharedContainerURL),
				databaseFilename: "medications"
			),
			let eventsEngine = SQLiteStorageEngine(
				directory: FileManager.Directory(url: sharedContainerURL),
				databaseFilename: "events"
			)
		else {
			fatalError("Unable to initialize watch widget data provider")
		}

		medicationsStore = Store<ANMedicationConcept>(
			storage: medicationsEngine,
			cacheIdentifier: \ANMedicationConcept.id.uuidString
		)

		eventsStore = Store<ANEventConcept>(
			storage: eventsEngine,
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

	/// Get medications sorted alphabetically by display name
	var medicationsByName: [ANMedicationConcept] {
		medications.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
	}

	/// Get the next medication due to be taken
	var nextMedicationDue: ANMedicationConcept? {
		medicationsByName.first
	}

	/// Get medication count
	var medicationCount: Int {
		medications.count
	}

	/// Get doses taken today
	var dosesToday: Int {
		let calendar = Calendar.current
		let today = calendar.startOfDay(for: Date())

		return events.filter { event in
			event.eventType == .doseTaken && calendar.isDate(event.date, inSameDayAs: today)
		}.count
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

	/// Default symbol based on medication unit type
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

	/// Display symbol with fallback to default
	var effectiveDisplaySymbol: String {
		symbolInfo?.name ?? defaultSymbol
	}
}
