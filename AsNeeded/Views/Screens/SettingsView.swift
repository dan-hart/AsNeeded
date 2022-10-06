//
//  SettingsView.swift
//  AsNeeded
//
//  Created by Dan Hart on 10/6/22.
//

import SwiftUI

struct SettingsView: View {
    @Binding var dose: Double
    @Binding var aheadTrajectoryInMG: Double
    
    var body: some View {
        VStack {
            DisclaimerView()

            Text("Dose")
                .font(.subheadline)
            AsNeededMGView(value: $dose)
                .padding(.bottom)
            
            Text("Ahead Trajectory Threshold")
                .font(.title)
            HStack {
                TrajectoryView(value: .ahead)
                AsNeededMGView(value: $aheadTrajectoryInMG, minimumValue: 1.0)
            }
        }
        .padding()
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(dose: .constant(5), aheadTrajectoryInMG: .constant(1.0))
    }
}
