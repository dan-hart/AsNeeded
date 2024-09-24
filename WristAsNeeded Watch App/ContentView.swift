//
//  ContentView.swift
//  WristAsNeeded Watch App
//
//  Created by Dan Hart on 9/24/24.
//

import SwiftUI
import SwiftData
import SwiftDate

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \LogItem.timestamp, order: .reverse) var logs: [LogItem]
    @Query var users: [User]
    
    var body: some View {
        VStack {
            Text("Today's Count")
            Text("\(logs.filter( { $0.timestamp.isToday }).roundedTotalMG) MG")
                .font(.title)
            Button {
                let log = LogItem(timestamp: Date(), quantityInMG: 1)
                modelContext.insert(log)
                users.first?.quantityInMG -= 1
                try? modelContext.save()
            } label: {
                Text("Quick Log 1")
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
