//
//  ContentView.swift
//  WristAsNeeded Watch App
//
//  Created by Dan Hart on 9/24/24.
//

import SwiftUI

struct ContentView: View {    
    @StateObject var sender = WCSender()
    
    var body: some View {
        VStack {
            if sender.isConnected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .padding(.bottom)
            } else {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red)
                    .padding(.bottom)
            }
            Text("Today's Medication")
            Text("TODO")
                .font(.title)
            Button {
                // TODO: Implement Apple Watch Logging
            } label: {
                Text("Quick Log")
            }
        }
        .padding()
    }
}

#if DEBUG
#Preview {
    ContentView()
}
#endif
