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
        TabView {
            MedicationListView()
                .environmentObject(sender)
                .tabItem {
                    Image(systemName: "pills")
                    Text("Medications")
                }

            ConnectionStatusView(sender: sender)
                .tabItem {
                    Image(systemName: "iphone.and.apple.watch")
                    Text("Status")
                }
        }
    }
}

struct ConnectionStatusView: View {
    @ObservedObject var sender: WCSender

    var body: some View {
        VStack(spacing: 16) {
            if sender.isConnected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.green)
                Text("Connected")
                    .font(.headline)
                Text("Your watch is connected to iPhone")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            } else {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.red)
                Text("Disconnected")
                    .font(.headline)
                Text("Make sure iPhone is nearby and AsNeeded app is open")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .navigationTitle("Connection")
    }
}

#if DEBUG
    #Preview {
        ContentView()
    }
#endif
