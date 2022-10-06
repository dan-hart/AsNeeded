//
//  PlanView.swift
//  AsNeeded
//
//  Created by Dan Hart on 10/6/22.
//

import SwiftUI

struct PlanView: View {
    var userData: UserData
    @State var plannedDailyDoseInMG: Double
    
    init(_ userData: UserData) {
        self.userData = userData
        plannedDailyDoseInMG = userData.dailyDoseInMG
    }
    
    var remainingQuantityInMG: Double {
        return userData.quantityInMG - ((userData.daysRemainingUntilNextRefillDate ?? 0) * plannedDailyDoseInMG)
    }
    
    var endOfCycleDailyTrimInMG: Double {
        return ((userData.refillQuantityInMG + remainingQuantityInMG) / Constants.daysInCycle) - userData.dailyDoseInMG
    }
    
    var explanation: String {
        return "If you take \(plannedDailyDoseInMG.formatted()) mg per day until \(userData.nextRefillDate.formatted(date: .abbreviated, time: .omitted)) (\(userData.daysRemainingUntilNextRefillDate?.formatted() ?? "No") \("day".pluralize(count: Int(userData.daysRemainingUntilNextRefillDate ?? 0))) from now) you will have \(remainingQuantityInMG.formatted()) mg left over."
    }
    
    var body: some View {
        VStack {
            Spacer()
            DisclaimerView()
            Text("Trajectory")
                .font(.title)
            TrajectoryView(value: Trajectory.calculate(forDailyTrimInMG: endOfCycleDailyTrimInMG))
            Text("\(endOfCycleDailyTrimInMG.rounded(toPlaces: 2).formatted()) mg daily trim at end of cycle")
            Text(explanation)
                .padding()
            Spacer()
            Text("Planned Daily Dose")
                .font(.title)
            AsNeededMGView(value: $plannedDailyDoseInMG)
                .padding(.bottom)
        }
        
        .navigationTitle("Plan")
    }
}

struct PlanView_Previews: PreviewProvider {
    static var previews: some View {
        PlanView(UserData())
    }
}
