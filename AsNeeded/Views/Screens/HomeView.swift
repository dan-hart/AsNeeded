//
//  HomeView.swift
//  AsNeeded
//
//  Created by Dan Hart on 1/17/23.
//

import SwiftUI
import SwiftData

#if os(iOS)
struct HomeView: View {
    @EnvironmentObject var userData: UserData
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack {
                    AsNeededDatePickerView(nextRefillDate: $userData.nextRefillDate)
                    Text("\(userData.daysRemainingUntilNextRefillDate?.formatted() ?? "N/A") \("day".pluralize(count: Int(userData.daysRemainingUntilNextRefillDate ?? 0))) remaining")
                        .font(.largeTitle)
                    #if os(iOS)
                    TrajectoryView(value: userData.currentStatus)
                    #endif
                    VStack(alignment: .leading) {
                        Text(userData.dailyAvailable)
                        Text(userData.dailyTrim)
                    }
                    QuantityView(quantity: $userData.quantityInMG)
                    QuickLogButton()
                        .environmentObject(userData)
                }
                .navigationTitle("Home")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        LogButtonView()
                            .environmentObject(userData)
                    }
                    
                    ToolbarItem {
                        QuickLogButton()
                            .environmentObject(userData)
                    }
                }
                .padding()
            }
        }
    }
}

#if DEBUG
#Preview {
    HomeView()
}
#endif
#endif
