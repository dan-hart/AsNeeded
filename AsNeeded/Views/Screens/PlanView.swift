//
//  PlanView.swift
//  AsNeeded
//
//  Created by Dan Hart on 10/6/22.
//

import SwiftUI
import SwiftData

struct PlanView: View {
    @StateObject var logbook = Logbook.shared
    
    var remainingQuantityInMG: Double {
        return logbook.user.quantityInMG - ((logbook.user.daysRemainingUntilNextRefillDate) * logbook.user.plannedDailyDoseInMG)
    }
    
    var remainingQuantityInDays: Double {
        return remainingQuantityInMG / logbook.user.dailyDoseInMG
    }
    
    var endOfCycleDailyTrimInMG: Double {
        return ((logbook.user.refillQuantityInMG + remainingQuantityInMG) / Constants.daysInCycle) - logbook.user.dailyDoseInMG
    }
    
    var explanation: String {
        return "If you take \(logbook.user.plannedDailyDoseInMG.formatted()) mg per day until \(logbook.user.nextRefillDate.formatted(date: .abbreviated, time: .omitted)) (\(logbook.user.daysRemainingUntilNextRefillDate.formatted()) \("day".pluralize(count: Int(logbook.user.daysRemainingUntilNextRefillDate))) from now) you will have \(remainingQuantityInMG.formatted()) mg left over which is a buffer of \(remainingQuantityInDays) \("day".pluralize(count: Int(remainingQuantityInDays)))."
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack {
                    Text("Trajectory")
                        .font(.title)
                    TrajectoryView(value: .ahead) // TODO: Implement
                    Text("\(endOfCycleDailyTrimInMG.rounded(toPlaces: 2).formatted()) mg daily trim at end of cycle")
                    Text(explanation)
                        .padding()
                    Spacer()
                    Text("Planned Daily Dose")
                        .font(.title)
                    AsNeededMGView(value: $logbook.user.plannedDailyDoseInMG)
                        .padding(.horizontal)
                        .padding(.bottom)
                }
                .navigationTitle("Plan")
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        NavigationLink {
                            TripView()
                        } label: {
                            Label("Trip", systemSymbol: .airplane)
                        }
                    }
                }
                .padding()
            }
        }
    }
}

#if DEBUG
#Preview {
    PlanView()
}
#endif
