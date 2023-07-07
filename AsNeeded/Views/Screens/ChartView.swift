//
//  ChartView.swift
//  AsNeeded
//
//  Created by Dan Hart on 7/7/23.
//

import SwiftUI
import Charts
import RealmSwift

struct ChartView: View {
    @ObservedResults(LogEntry.self) var logs
    
    private let sortDescriptors = [
        SortDescriptor(keyPath: "timestamp", ascending: false)
    ]
    
    var last30DaysLogs: [LogEntry] {
        return logs.sorted(by: sortDescriptors).filter { log in
            return log.timestamp.isInRange(date: Date().dateByAdding(Int(-Constants.daysInCycle), .day).date, and: Date())
        }
    }
    
    @State var yMax = 10
    
    var body: some View {
        VStack {
            Text("Visualization")
            Spacer()
            Chart {
                ForEach(last30DaysLogs, id: \.self) { log in
                    BarMark(
                        x: .value("Date", log.timestamp),
                        y: .value("Total", log.quantityInMG)
                    )
                }
            }
            .chartYScale(domain: [0, yMax])
            .padding()
            Spacer()
            Stepper("", value: $yMax, in: 0...15)
                .labelsHidden()
            Spacer()
        }
    }
}

struct ChartView_Previews: PreviewProvider {
    static var previews: some View {
        ChartView()
    }
}
