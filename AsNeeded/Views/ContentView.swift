//
//  ContentView.swift
//  AsNeeded
//
//  Created by Dan Hart on 10/6/22.
//

import SwiftUI
import SFSafeSymbols
import SwiftData

struct ContentView: View {
    @EnvironmentObject var userData: UserData
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) var scenePhase
    
    @StateObject var logbook = Logbook.shared
    @StateObject var receiver = WCReceiver()
    
    var body: some View {
        TabView {
            HomeView()
                .environmentObject(userData)
                .tabItem {
                    Label("Home", systemSymbol: .house)
                }
            
            LogbookView()
                .environmentObject(userData)
                .tabItem {
                    Label("Logbook", systemSymbol: .docPlaintext)
                }
            
            PlanView()
                .environmentObject(userData)
                .tabItem {
                    Label("Plan", systemSymbol: .arrowUpRight)
                }
            
            ChartView()
                .environmentObject(userData)
                .tabItem {
                    Label("Visual", systemSymbol: .chartBar)
                }
            
            SettingsView(dose: $userData.dailyDoseInMG, refillQuantity: $userData.refillQuantityInMG, aheadTrajectoryInMG: $userData.aheadTrajectoryInMG)
                .environmentObject(userData)
                .tabItem {
                    Label("Settings", systemSymbol: .gearshape)
                }
        }
        .onAppear {
            receiver.onMessageReceived = { messages in
                for message in messages {
                    if message.key == "log_quantity" {
                        let quantity = message.value as? Double ?? -1
                        if quantity > 0 {
                            userData.quantityInMG -= quantity
                        }
                    }
                }
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
