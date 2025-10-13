//
//  ContentView.swift
//  AsNeeded
//
//  Created by Dan Hart on 10/6/22.
//

import SwiftUI
import SFSafeSymbols

struct ContentView: View {
	@AppStorage(UserDefaultsKeys.hasSeenWelcome) private var hasSeenWelcome: Bool = false
	@AppStorage(UserDefaultsKeys.shouldShowWelcomeOnNextLaunch) private var shouldShowWelcomeOnNextLaunch: Bool = false
	@AppStorage(UserDefaultsKeys.selectedFontFamily) private var selectedFontFamily: String = FontFamily.system.rawValue
	@StateObject private var navigationManager = NavigationManager.shared
	@EnvironmentObject private var quickActionHandler: QuickActionHandler
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
			.tint(.accent)
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
		.onQuickAction { action in
			handleQuickAction(action)
		}
		.fontFamily(currentFontFamily)
	}

	// MARK: - Quick Action Handler
	private func handleQuickAction(_ action: QuickActionHandler.QuickAction) {
		// Ensure welcome screen is dismissed first
		guard hasSeenWelcome else {
			// Defer action until after welcome screen
			DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
				handleQuickAction(action)
			}
			return
		}

		switch action {
		case .logDose(let medicationID):
			// Navigate to medications tab
			navigationManager.selectedTab = 0
			// If medicationID provided, the medication list will handle showing log sheet
			// This could be enhanced with a published property in NavigationManager
			if let medicationID = medicationID {
				// Store the medication ID to log in NavigationManager for pickup
				// This is a future enhancement
				print("Quick action: Log dose for medication \(medicationID)")
			}

		case .viewHistory:
			navigationManager.selectedTab = 1

		case .addMedication:
			// Navigate to medications tab
			// The add medication flow will be triggered by the medication list view
			navigationManager.selectedTab = 0

		case .viewTrends:
			navigationManager.selectedTab = 2
		}

		// Clear the action after handling
		quickActionHandler.clearPendingAction()
	}
}

#if DEBUG
#Preview {
	ContentView()
}
#endif