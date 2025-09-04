//
//  ContentView.swift
//  AsNeeded
//
//  Created by AsNeeded Team on 10/6/22.
//

import SwiftUI
import SFSafeSymbols
import HealthKit

struct ContentView: View {
	@AppStorage("hasSeenWelcome") private var hasSeenWelcome: Bool = false
	
	var body: some View {
		ZStack {
			TabView {
				MedicationView()
					.tabItem {
						Label("Medication", systemSymbol: .pills)
					}
				HistoryView()
					.tabItem {
						Label("History", systemSymbol: .clockArrowTriangleheadCounterclockwiseRotate90)
					}
				TrendsView()
					.tabItem {
						Label("Trends", systemSymbol: .chartXyaxisLine)
					}
				SettingsView()
					.tabItem {
						Label("Settings", systemSymbol: .gearshape)
					}
			}
		}
		.fullScreenCover(isPresented: .constant(!hasSeenWelcome)) {
			WelcomeView()
		}
	}
}

#if DEBUG
#Preview {
	ContentView()
}
#endif
