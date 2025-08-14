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
    @Binding var toggleHealthDataAuthorization: Bool
    @Binding var healthDataAuthorized: Bool?
    
    @AppStorage("showWelcome") private var showWelcome: Bool = true
    
    var healthStore: HKHealthStore { HealthStore.shared.healthStore }
    
    init(toggleHealthDataAuthorization: Binding<Bool>,
         healthDataAuthorized: Binding<Bool?>) {
        self._toggleHealthDataAuthorization = toggleHealthDataAuthorization
        self._healthDataAuthorized = healthDataAuthorized
    }
    
    var body: some View {
        ZStack {
            TabView {
                MedicationView()
                    .tabItem {
                        Label("Medication", systemImage: "pills")
                    }
                HistoryView()
                    .tabItem {
                        Label("History", systemImage: "clock.arrow.circlepath")
                    }
                TrendsView()
                    .tabItem {
                        Label("Trends", systemImage: "chart.xyaxis.line")
                    }
                SettingsView()
                    .tabItem {
                        Label("Settings", systemImage: "gearshape")
                    }
            }
            .disabled(showWelcome)
            .blur(radius: showWelcome ? 6 : 0)
            if showWelcome {
                WelcomeView {
                    withAnimation { showWelcome = false }
                }
                .transition(.opacity.combined(with: .scale))
                .zIndex(1)
            }
        }
    }
}

#if DEBUG
#Preview {
    ContentView(toggleHealthDataAuthorization: .constant(false), healthDataAuthorized: .constant(true))
}
#endif
