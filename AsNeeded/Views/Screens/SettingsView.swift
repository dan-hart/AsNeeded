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
    
    var body: some View {
        VStack {
            DisclaimerView()

            HStack {
                VStack {
                    Text("Dose")
                        .font(.subheadline)
                    AsNeededMGView(value: $dose)
                }
                VStack {
                    Text("Refill Quantity")
                        .font(.subheadline)
                    AsNeededMGView(value: $refillQuantity)
                }
            }
            .padding(.bottom)
            
            Text("Ahead Trajectory Threshold")
                .font(.title)
            HStack {
                TrajectoryView(value: .ahead)
                AsNeededMGView(value: $aheadTrajectoryInMG, minimumValue: 1.0)
            }
        }
        .padding()
        
        .navigationTitle("Settings")
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(dose: .constant(5), refillQuantity: .constant(150), aheadTrajectoryInMG: .constant(1.0))
    }
}
