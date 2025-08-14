//
//  AsNeededApp.swift
//  AsNeeded
//
//  Created by Dan Hart on 9/26/22.
//

import SwiftUI
import HealthKit
import HealthKitUI

@main
struct AsNeededApp: App {
    private let healthStore = HealthStore.shared.healthStore

    @State var triggerMedicationsAuthorization: Bool = false
    @State var healthDataAuthorized: Bool?
    
    var body: some Scene {
        WindowGroup {
            ContentView(toggleHealthDataAuthorization: $triggerMedicationsAuthorization,
                        healthDataAuthorized: $healthDataAuthorized)
            .onAppear {
                triggerMedicationsAuthorization.toggle()
            }
            .healthDataAccessRequest(store: healthStore,
                                     objectType: .userAnnotatedMedicationType(),
                                     trigger: triggerMedicationsAuthorization,
                                     completion: { @Sendable result in
                Task { @MainActor in
                    switch result {
                    case .success:
                        healthDataAuthorized = true
                    case .failure(let error):
                        print("Error when requesting HealthKit read authorizations: \(error)")
                    }
                }
            })
        }
    }
}
