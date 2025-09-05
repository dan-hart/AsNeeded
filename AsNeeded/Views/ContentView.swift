//
//  ContentView.swift
//  AsNeeded
//
//  Created by Dan Hart on 10/6/22.
//

import SwiftUI
import SFSafeSymbols
import HealthKit

struct ContentView: View {
	@AppStorage("hasSeenWelcome") private var hasSeenWelcome: Bool = false
	@StateObject private var navigationManager = NavigationManager.shared
	
	var body: some View {
		ZStack {
			TabView(selection: $navigationManager.selectedTab) {
				MedicationView()
					.tabItem {
						Label("Medication", systemSymbol: .pills)
					}
					.tag(0)
				HistoryView()
					.tabItem {
						Label("History", systemSymbol: .clockArrowTriangleheadCounterclockwiseRotate90)
					}
					.tag(1)
				TrendsView()
					.tabItem {
						Label("Trends", systemSymbol: .chartXyaxisLine)
					}
					.tag(2)
				SettingsView()
					.tabItem {
						Label("Settings", systemSymbol: .gearshape)
					}
					.tag(3)
			}
			.environmentObject(navigationManager)
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