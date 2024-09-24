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
            Text("Today's Count")
            Text("\(logs.filter( { $0.timestamp.isToday }).roundedTotalMG) MG")
                .font(.title)
            Button {
                let log = LogItem(timestamp: Date(), quantityInMG: 1)
                modelContext.insert(log)
                try? modelContext.save()
                sender.sendMessage(key: "log_quantity", value: 1)
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
