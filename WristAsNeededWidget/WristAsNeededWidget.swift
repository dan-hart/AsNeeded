//
//  WristAsNeededWidget.swift
//  WristAsNeededWidget
//
//  Watch complications for AsNeeded medication tracking
//

import ANModelKit
import SwiftUI
import WidgetKit

@main
struct WristAsNeededWidgets: WidgetBundle {
	var body: some Widget {
		NextMedicationWidget()
		MedicationCountWidget()
	}
}
