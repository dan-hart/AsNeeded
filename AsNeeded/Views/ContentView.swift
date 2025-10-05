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
	@AppStorage(UserDefaultsKeys.hasSeenWelcome) private var hasSeenWelcome: Bool = false
	@AppStorage(UserDefaultsKeys.shouldShowWelcomeOnNextLaunch) private var shouldShowWelcomeOnNextLaunch: Bool = false
	@AppStorage(UserDefaultsKeys.selectedFontFamily) private var selectedFontFamily: String = FontFamily.system.rawValue
	@StateObject private var navigationManager = NavigationManager.shared
	private let hapticsManager = HapticsManager.shared

	private var currentFontFamily: FontFamily {
		FontFamily(rawValue: selectedFontFamily) ?? .system
	}
	
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
			.onChange(of: navigationManager.selectedTab) { _, _ in
				hapticsManager.selectionChanged()
			}
			.environmentObject(navigationManager)
		}
		.fullScreenCover(isPresented: .constant(!hasSeenWelcome)) {
			WelcomeView()
		}
		.onAppear {
			// Check if we should reset and show welcome on this launch
			if shouldShowWelcomeOnNextLaunch {
				// Reset the flag first
				shouldShowWelcomeOnNextLaunch = false
				// Then reset hasSeenWelcome to show the welcome screen
				hasSeenWelcome = false
			}
		}
		.onChange(of: currentFontFamily) { _, newFamily in
			// Update navigation bar appearance when font family changes
			NavigationBarAppearanceManager.configureAppearance(for: newFamily)
		}
		.fontFamily(currentFontFamily)
	}
}

#if DEBUG
#Preview {
	ContentView()
}
#endif