//
//  LogEntryRowView.swift
//  AsNeeded
//
//  Created by Dan Hart on 1/17/23.
//

import SwiftUI
import SwiftDate

struct LogEntryRowView: View {
    var log: LogEntry
    var here = Date()
    
    var body: some View {
        VStack {
            HStack {
                Text("\(log.roundedQuantityInMG) mg")
                Spacer()
                Text("taken \(log.timestamp.toRelative(since: DateInRegion(year: here.year, month: here.month, day: here.day, hour: here.hour, minute: here.minute, second: here.second, nanosecond: here.nanosecond, region: here.region)))")
            }
            HStack {
                Spacer()
                Text(log.timestamp.formatted(.dateTime))
            }
            
            Divider()
        }
    }
}

struct LogEntryRowView_Previews: PreviewProvider {
    static var previews: some View {
        LogEntryRowView(log: LogEntry.preview())
    }
}
