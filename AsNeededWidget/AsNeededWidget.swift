//
//  AsNeededWidget.swift
//  AsNeededWidget
//
//  Main widget entry point for AsNeeded medication tracking widgets
//

import WidgetKit
import SwiftUI
import ANModelKit

@main
struct AsNeededWidgets: WidgetBundle {
	var body: some Widget {
		MedicationSmallWidget()
		MedicationMediumWidget()
		MedicationLargeWidget()
		MedicationLockScreenWidget()
	}
}
