//
//  ContentView.swift
//  AsNeeded
//
//  Created by Dan Hart on 10/6/22.
//

import SwiftUI
import SwiftyUserDefaults
import SFSafeSymbols

struct ContentView: View {
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
                
                ChartView()
                    .tabItem {
                        Label("Visual", systemSymbol: .chartBar)
                    }
                
                TripView()
                    .tabItem {
                        Label("Trip", systemSymbol: .airplane)
                    }
                
                PlanView()
                    .tabItem {
                        Label("Plan", systemSymbol: .arrowUpRight)
                    }
                
                SettingsView(dose: $userData.dailyDoseInMG, refillQuantity: $userData.refillQuantityInMG, aheadTrajectoryInMG: $userData.aheadTrajectoryInMG)
                    .tabItem {
                        Label("Settings", systemSymbol: .gearshape)
                    }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
