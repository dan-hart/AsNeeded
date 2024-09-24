//
//  ChartView.swift
//  AsNeeded
//
//  Created by Dan Hart on 7/7/23.
//

import SwiftUI
import Charts
import SwiftData

struct ChartView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \LogItem.timestamp, order: .reverse) var logs: [LogItem]
    
    @Query(filter: LogItem.last30DaysPredicate(),
           sort: \LogItem.timestamp
       ) var last30DaysLogs: [LogItem]
    
    var last30DaysLogsGrouped: [LogItem] {
        // group by day, if timestamp is within the same day
        let grouped = last30DaysLogs.map({$0}).groupedByDate()
        // convert to 1d array with summed values
        let summedLogs = grouped.mapValues { logs in
            let total = logs.reduce(0) { $0 + $1.quantityInMG }
            let entry = LogItem()
            entry.timestamp = logs.first!.timestamp
            entry.quantityInMG += total
            return entry
        }
        return summedLogs.values.map({$0})
    }
    
    var last30DaysQuantity: [Double] {
        groupLogsByDate(logs: last30DaysLogs)
    }
    
    var last7DaysQuantity: [Double] {
        let last7 = last30DaysLogs.suffix(7).map({$0})
        return groupLogsByDate(logs: last7)
    }
    
    @State var yMax = 10
    
    var body: some View {
        NavigationStack {
            VStack {
                Chart {
                    ForEach(last30DaysLogsGrouped, id: \.self) { entry in
                        BarMark(
                            x: .value("Date", entry.timestamp.date),
                            y: .value("Total", entry.quantityInMG)
                        )
                    }
                }
                .chartYScale(domain: [0, yMax])
                .padding()
                Spacer()
                Stepper("", value: $yMax, in: 0...15)
                    .labelsHidden()
                Spacer()
                
                HStack {
                    Text("30-day Trend")
                        .font(.title)
                        .multilineTextAlignment(.leading)
                    Spacer()
                    TrendView(trend: TrendAnalyzer.trend(numbers: last30DaysQuantity))
                }
                .padding()
                
                HStack {
                    Text("7-day Trend")
                        .font(.title)
                        .multilineTextAlignment(.leading)
                    Spacer()
                    TrendView(trend: TrendAnalyzer.trend(numbers: last7DaysQuantity))
                }
                .padding()
                
                Spacer()
            }
            .navigationTitle("Visualization")
        }
    }
    
    func groupLogsByDate(logs: [LogItem]) -> [Double] {
        let grouped = Dictionary(grouping: logs) { log in
            return log.timestamp.date
        }
        let summedLogs = grouped.mapValues { logs in
            logs.reduce(0) { $0 + $1.quantityInMG }
        }
        return summedLogs.values.sorted()
    }
}

#if DEBUG
#Preview {
    ChartView()
        .environmentObject(UserData.preview)
}
#endif
