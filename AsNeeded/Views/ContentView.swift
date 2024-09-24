//
//  ContentView.swift
//  AsNeeded
//
//  Created by Dan Hart on 10/6/22.
//

import SwiftUI
import SwiftyUserDefaults
import SFSafeSymbols
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) var scenePhase
    
    @EnvironmentObject var userData: UserData
    
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("Home", systemSymbol: .house)
                }
            
            LogbookView()
                .tabItem {
                    Label("Logbook", systemSymbol: .docPlaintext)
                }
            
            PlanView()
                .tabItem {
                    Label("Plan", systemSymbol: .arrowUpRight)
                }
            
            ChartView()
                .tabItem {
                    Label("Visual", systemSymbol: .chartBar)
                }
            
            SettingsView(dose: $userData.dailyDoseInMG, refillQuantity: $userData.refillQuantityInMG, aheadTrajectoryInMG: $userData.aheadTrajectoryInMG)
                .tabItem {
                    Label("Settings", systemSymbol: .gearshape)
                }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background {
                if modelContext.hasChanges {
                    try? modelContext.save()
                }
            }
        }
    }
}

#if DEBUG
#Preview {
    ContentView()
        .environmentObject(UserData.preview)
}
#endif
