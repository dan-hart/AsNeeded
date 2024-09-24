//
//  ContentView.swift
//  WristAsNeeded Watch App
//
//  Created by Dan Hart on 9/24/24.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query var logs: [LogItem]
    
    var body: some View {
        VStack {
            Text("Today's Count: \(logs.roundedTotalMG)")
            Button {
                let log = LogItem(timestamp: Date(), quantityInMG: 1)
                modelContext.insert(log)
                if modelContext.hasChanges {
                    try? modelContext.save()
                }
            } label: {
                Text("Quick Log 1")
            }
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
