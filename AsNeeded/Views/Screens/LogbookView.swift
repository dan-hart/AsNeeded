//
//  LogbookView.swift
//  AsNeeded
//
//  Created by Dan Hart on 1/17/23.
//

import SwiftUI
import SwiftData
import SwiftDate

struct LogbookView: View {
    @EnvironmentObject var userData: UserData
    
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \LogItem.timestamp, order: .reverse) var logs: [LogItem]
    @State var date2DArray: [[LogItem]] = [
        [LogItem()],
        [LogItem()],
        [LogItem()],
    ]
    @State private var isLoading = false
    
    var body: some View {
        NavigationStack {
            List {
                if date2DArray.isEmpty {
                    Text("No logs found")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(date2DArray, id: \.self) { dayLogs in
                        Section(header: Text("\((dayLogs.first?.timestamp ?? Date()).formatted(date: .abbreviated, time: .omitted)) - \("Total: \(dayLogs.roundedTotalMG) MG")")) {
                            ForEach(dayLogs) { log in
                                NavigationLink(destination: LogItemDetailView(logItem: log).environmentObject(userData)) {
                                    LogEntryRowView(log: log)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Logbook")
        }
        .redacted(reason: isLoading ? .placeholder : [])
        .task {
            isLoading = true
            defer { isLoading = false }
            date2DArray = await logs.groupedByDate2DArray()
        }
    }
}

#if DEBUG
#Preview {
    LogbookView()
        .environment(\.modelContext, Logbook.shared.context)
}
#endif
