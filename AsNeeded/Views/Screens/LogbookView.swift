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
    
    var body: some View {
        NavigationStack {
            List {
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
            .navigationTitle("Logbook")
        }
        .redacted(reason: date2DArray.count > 3 ? [] : .placeholder)
        .task {
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
