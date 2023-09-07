//
//  SettingsView.swift
//  AsNeeded
//
//  Created by Dan Hart on 10/6/22.
//

import SwiftUI

struct SettingsView: View {
    @Binding var dose: Double
    @Binding var refillQuantity: Double
    @Binding var aheadTrajectoryInMG: Double
    
    @EnvironmentObject var userData: UserData
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack {
                    DisclaimerView()
                    
                    Text("Dose")
                        .font(.subheadline)
                    AsNeededMGView(value: $dose)
                    
                    Text("Refill Quantity")
                        .font(.subheadline)
                    AsNeededMGView(value: $refillQuantity)
                    
                    Text("Ahead Trajectory Threshold")
                        .font(.title)
                    VStack {
                        TrajectoryView(value: .ahead)
                        AsNeededMGView(value: $aheadTrajectoryInMG, minimumValue: 1.0)
                    }
                    
                    RefillButtonView()
                        .padding()
                }
                .navigationTitle("Settings")
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

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(dose: .constant(5), refillQuantity: .constant(150), aheadTrajectoryInMG: .constant(1.0))
    }
}
