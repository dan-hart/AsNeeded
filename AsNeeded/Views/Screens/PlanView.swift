//
//  PlanView.swift
//  AsNeeded
//
//  Created by Dan Hart on 10/6/22.
//

import SwiftUI

struct PlanView: View {
    @EnvironmentObject var userData: UserData
    
    var remainingQuantityInMG: Double {
        return userData.quantityInMG - ((userData.daysRemainingUntilNextRefillDate ?? 0) * userData.plannedDailyDoseInMG)
    }
    
    var remainingQuantityInDays: Double {
        return remainingQuantityInMG / userData.dailyDoseInMG
    }
    
    var endOfCycleDailyTrimInMG: Double {
        return ((userData.refillQuantityInMG + remainingQuantityInMG) / Constants.daysInCycle) - userData.dailyDoseInMG
    }
    
    var explanation: String {
        return "If you take \(userData.plannedDailyDoseInMG.formatted()) mg per day until \(userData.nextRefillDate.formatted(date: .abbreviated, time: .omitted)) (\(userData.daysRemainingUntilNextRefillDate?.formatted() ?? "No") \("day".pluralize(count: Int(userData.daysRemainingUntilNextRefillDate ?? 0))) from now) you will have \(remainingQuantityInMG.formatted()) mg left over which is a buffer of \(remainingQuantityInDays) \("day".pluralize(count: Int(remainingQuantityInDays)))."
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack {
                    Text("Trajectory")
                        .font(.title)
                    TrajectoryView(value: Trajectory.calculate(forDailyTrimInMG: endOfCycleDailyTrimInMG))
                    Text("\(endOfCycleDailyTrimInMG.rounded(toPlaces: 2).formatted()) mg daily trim at end of cycle")
                    Text(explanation)
                        .padding()
                    Spacer()
                    Text("Planned Daily Dose")
                        .font(.title)
                    AsNeededMGView(value: $userData.plannedDailyDoseInMG)
                        .padding(.horizontal)
                        .padding(.bottom)
                }
                .navigationTitle("Plan")
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        NavigationLink {
                            TripView()
                                .environmentObject(userData)
                        } label: {
                            Label("Trip", systemSymbol: .airplane)
                        }
                    }
                    
                    ToolbarItem(placement: .topBarTrailing) {
                        LogButtonView()
                    }
                    
                    ToolbarItem {
                        QuickLogButton()
                    }
                }
                .padding()
            }
        }
    }
}

struct PlanView_Previews: PreviewProvider {
    static var previews: some View {
        PlanView()
            .environmentObject(UserData())
    }
}
