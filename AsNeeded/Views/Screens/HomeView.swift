//
//  HomeView.swift
//  AsNeeded
//
//  Created by Dan Hart on 1/17/23.
//

import SwiftUI

struct HomeView: View {
    @EnvironmentObject var userData: UserData
    
    var body: some View {
        NavigationStack {
            VStack {
                DisclaimerView()
                AsNeededDatePickerView(nextRefillDate: $userData.nextRefillDate)
                Text("\(userData.daysRemainingUntilNextRefillDate?.formatted() ?? "No") \("day".pluralize(count: Int(userData.daysRemainingUntilNextRefillDate ?? -1))) remaining")
                    .font(.largeTitle)
                TrajectoryView(value: userData.currentStatus)
                VStack(alignment: .leading) {
                    Text(userData.dailyAvailable)
                    Text(userData.dailyTrim)
                }
                .padding()
                QuantityView(quantity: $userData.quantityInMG)
                    .padding(.bottom)
            }
            .onAppear {
                // Trigger re-calculation in case the day has changed
                userData.daysRemainingUntilNextRefillDate = userData.calculateDaysRemainingUntilNextRefillDate()
            }
            
            .navigationTitle("Home")
        }
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
    }
}
