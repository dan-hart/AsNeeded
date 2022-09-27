//
//  ContentView.swift
//  AsNeeded
//
//  Created by Dan Hart on 9/26/22.
//

import SwiftUI

struct ContentView: View {
    @State var isLoading = false
    @State var isHealthDataAvailable = false
    @State var isHealthDataAuthorized = false
    
    var body: some View {
        VStack {
            if isHealthDataAvailable {
                if isHealthDataAuthorized {
                    Text("Ready")
                } else {
                    if isLoading {
                        Text("Loading...")
                    } else {
                        Button {
                            Task { await authorize() }
                        } label: {
                            Text("Authorize")
                        }
                    }
                }
            } else {
                Text("Health data is not available.")
            }
        }
        .task {
            await authorize()
        }
        .padding()
    }
    
    func authorize() async {
        isLoading = true
        
        if HealthDataAccessor.shared.isAvailable {
            isHealthDataAvailable = true
        } else { isHealthDataAvailable = false }
        
        isHealthDataAuthorized = await HealthDataAccessor.shared.requestClinicalMedicationPermission()
        
        isLoading = false
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
