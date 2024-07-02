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
            ScrollView {
                VStack {
                    AsNeededDatePickerView(nextRefillDate: $userData.nextRefillDate)
                    Text("\(userData.daysRemainingUntilNextRefillDate?.formatted() ?? "No") \("day".pluralize(count: Int(userData.daysRemainingUntilNextRefillDate ?? -1))) remaining")
                        .font(.largeTitle)
                    TrajectoryView(value: userData.currentStatus)
                    VStack(alignment: .leading) {
                        Text(userData.dailyAvailable)
                        Text(userData.dailyTrim)
                    }
                    QuantityView(quantity: $userData.quantityInMG)
                    QuickLogButton()
                }
                .navigationTitle("Home")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        LogButtonView()
                    }
                    
                    ToolbarItem {
                        QuickLogButton()
                    }
                }
                .onAppear {
                    // Trigger re-calculation in case the day has changed
                    userData.daysRemainingUntilNextRefillDate = userData.calculateDaysRemainingUntilNextRefillDate()
                }
                .padding()
            }
        }
    }
}

#Preview { 
    HomeView()
        .environmentObject(UserData.preview)
}
