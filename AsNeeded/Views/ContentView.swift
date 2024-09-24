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
    
    @StateObject var logbook = Logbook.shared
    
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
            
            SettingsView(dose: $logbook.user.dailyDoseInMG, refillQuantity: $logbook.user.refillQuantityInMG, aheadTrajectoryInMG: $logbook.user.aheadTrajectoryInMG)
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
}
#endif
