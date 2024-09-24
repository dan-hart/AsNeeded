//
//  LogEntryRowView.swift
//  AsNeeded
//
//  Created by Dan Hart on 1/17/23.
//

import SwiftUI
import SwiftDate

struct LogEntryRowView: View {
    var log: LogItem
    var here = Date()
    
    var body: some View {
        VStack {
            HStack {
                Text("\(log.roundedQuantityInMG) mg at \(log.timestamp.formatted(date: .omitted, time: .shortened))")
                Spacer()
                Text("\(log.timestamp.toRelative(since: DateInRegion(year: here.year, month: here.month, day: here.day, hour: here.hour, minute: here.minute, second: here.second, nanosecond: here.nanosecond, region: here.region)))")
            }
        }
    }
}

#if DEBUG
#Preview {
    LogEntryRowView(log: LogItem.preview(), here: Date())
}
#endif
