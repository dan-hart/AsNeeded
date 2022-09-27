//
//  ContentView.swift
//  AsNeeded
//
//  Created by Dan Hart on 9/26/22.
//

import SwiftUI

struct ContentView: View {
    @State var isHealthDataAvailable = false
    @State var isHealthDataAuthorized = false
    
    var body: some View {
        VStack {
            if isHealthDataAvailable {
                if isHealthDataAuthorized {
                    Text("Ready")
                } else {
                    Button {
                        Task { await authorize() }
                    } label: {
                        Text("Authorize")
                    }

                }
            } else {
                Text("Health data is not available.")
            }
        }
        .padding()
    }
    
    func authorize() async {
        if HealthDataAccessor.shared.isAvailable {
            isHealthDataAvailable = true
        } else { return }
        
        isHealthDataAuthorized = await HealthDataAccessor.shared.requestClinicalMedicationPermission()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
