//
//  AsNeededWidget.swift
//  AsNeededWidget
//
//  Main widget entry point for AsNeeded medication tracking widgets
//

import ANModelKit
import SwiftUI
import WidgetKit

@main
struct AsNeededWidgets: WidgetBundle {
    var body: some Widget {
        MedicationSmallWidget()
        MedicationMediumWidget()
        MedicationLargeWidget()
        MedicationLockScreenWidget()
        if #available(iOSApplicationExtension 16.2, *) {
            MedicationLiveActivityWidget()
        }
    }
}
