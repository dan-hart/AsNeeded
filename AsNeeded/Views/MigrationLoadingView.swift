// MigrationLoadingView.swift
// Medication tab preview shown while startup prepares local data.

import SFSafeSymbols
import SwiftUI

struct MigrationLoadingView: View {
	var body: some View {
		TabView(selection: .constant(0)) {
			NavigationStack {
				MedicationLoadingRows()
					.customNavigationTitle("Medication", displayMode: .large)
			}
			.tabItem { Label("Medication", systemSymbol: .pills) }
			.tag(0)

			Color.clear
				.tabItem { Label("History", systemSymbol: .clockArrowTriangleheadCounterclockwiseRotate90) }
				.tag(1)

			Color.clear
				.tabItem { Label("Trends", systemSymbol: .chartXyaxisLine) }
				.tag(2)

			Color.clear
				.tabItem { Label("Settings", systemSymbol: .gearshape) }
				.tag(3)
		}
		.tint(.accent)
		.allowsHitTesting(false)
		.accessibilityElement(children: .ignore)
		.accessibilityLabel(Text("Loading Your Data"))
	}
}

#Preview("Light") {
	MigrationLoadingView()
		.preferredColorScheme(.light)
}

#Preview("Dark") {
	MigrationLoadingView()
		.preferredColorScheme(.dark)
}

#Preview("Accessibility Size") {
	MigrationLoadingView()
		.dynamicTypeSize(.accessibility3)
}
