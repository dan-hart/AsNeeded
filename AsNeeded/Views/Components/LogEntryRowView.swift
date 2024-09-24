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
                Text("\(log.roundedQuantityInMG) mg")
                Spacer()
                Text("\(log.timestamp.formatted(date: .omitted, time: .shortened))")
            }
        }
    }
}

#if DEBUG
#Preview {
    LogEntryRowView(log: LogItem.preview(), here: Date())
}
#endif
