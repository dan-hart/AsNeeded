//
//  SettingsView.swift
//  AsNeeded
//
//  Created by Dan Hart on 10/6/22.
//

import SwiftUI
import SwiftData
import RealmSwift

// Backup of Realm Data as of 09/24/2024
class LogEntry: Object {
    @Persisted(primaryKey: true) var _id: String
    
    @Persisted var timestamp: Date
    @Persisted var quantityInMG: Double

    var roundedQuantityInMG: String {
        "\(quantityInMG.rounded(toPlaces: 1))"
    }
}

extension LogEntry: Identifiable { }


struct SettingsView: View {    
    @Binding var dose: Double
    @Binding var refillQuantity: Double
    @Binding var aheadTrajectoryInMG: Double
    
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
}
#endif
