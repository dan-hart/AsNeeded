//
//  HomeView.swift
//  AsNeeded
//
//  Created by Dan Hart on 1/17/23.
//

import SwiftUI
import SwiftData

struct HomeView: View {
    @StateObject var logbook = Logbook.shared
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack {
                    AsNeededDatePickerView(nextRefillDate: $logbook.user.nextRefillDate)
                    Text("\(logbook.user.daysRemainingUntilNextRefillDate.formatted()) \("day".pluralize(count: Int(logbook.user.daysRemainingUntilNextRefillDate))) remaining")
                        .font(.largeTitle)
                    TrajectoryView(value: logbook.user.currentStatus)
                    VStack(alignment: .leading) {
                        Text(logbook.user.dailyAvailable)
                        Text(logbook.user.dailyTrim)
                    }
                    QuantityView(quantity: $logbook.user.quantityInMG)
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
