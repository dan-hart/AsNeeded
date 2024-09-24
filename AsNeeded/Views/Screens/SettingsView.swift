//
//  SettingsView.swift
//  AsNeeded
//
//  Created by Dan Hart on 10/6/22.
//

import SwiftUI
import SwiftData

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
                .padding()
            }
        }
    }
}

#if DEBUG
#Preview {
    SettingsView(dose: .constant(5), refillQuantity: .constant(150), aheadTrajectoryInMG: .constant(1.0))
        .environmentObject(UserData.preview)
}
#endif
