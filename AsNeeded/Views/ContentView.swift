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
    @State var showSettings = false
    @State var showPlan = false
    
    @EnvironmentObject var userData: UserData
    
    var body: some View {
        NavigationStack {
            VStack {
                DisclaimerView()
                ScrollView {
                    AsNeededDatePickerView(nextRefillDate: $userData.nextRefillDate)
                    Text("\(userData.daysRemainingUntilNextRefillDate?.formatted() ?? "No") \("day".pluralize(count: Int(userData.daysRemainingUntilNextRefillDate ?? -1))) remaining")
                        .font(.largeTitle)
                    TrajectoryView(value: userData.currentStatus)
                    VStack(alignment: .leading) {
                        Text(userData.dailyAvailable)
                        Text(userData.dailyTrim)
                    }
                    .padding()
                    
                    Button {
                        showPlan.toggle()
                    } label: {
                        Label("Plan", systemSymbol: .airplaneDeparture)
                    }
                }
                Spacer()
                QuantityView(quantity: $userData.quantityInMG)
                    .padding(.bottom)
            }
            .toolbar {
                ToolbarItem {
                    Button {
                        showSettings.toggle()
                    } label: {
                        Image(systemSymbol: .gearCircle)
                    }
                }
            }
            .sheet(isPresented: $showPlan) {
                PlanView()
                    .presentationDetents([.fraction(0.75), .fraction(1)])
            }
            .sheet(isPresented: $showSettings) {
                SettingsView(dose: $userData.dailyDoseInMG, refillQuantity: $userData.refillQuantityInMG, aheadTrajectoryInMG: $userData.aheadTrajectoryInMG)
                    .presentationDetents([.fraction(0.75), .fraction(1)])
            }
            .onAppear {
                // Trigger re-calculation in case the day has changed
                userData.daysRemainingUntilNextRefillDate = userData.calculateDaysRemainingUntilNextRefillDate()
            }
            
            .navigationTitle("AsNeeded")
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
