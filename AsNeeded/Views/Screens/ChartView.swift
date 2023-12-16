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
        // get logs from last 30 days grouped by date
        guard let last30Days = Calendar.current.date(byAdding: .day, value: -30, to: Date()) else { return [] }
        let last30DaysLogs = logs.filter("timestamp >= %@", last30Days).sorted(by: sortDescriptors)
        // group by day, if timestamp is within the same day
        let grouped = last30DaysLogs.map({$0}).groupedByDate()
        // convert to 1d array with summed values
        let summedLogs = grouped.mapValues { logs in
            let total = logs.reduce(0) { $0 + $1.quantityInMG }
            let entry = LogEntry()
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
    
    @State var yMax = 7
    
    var body: some View {
        NavigationStack {
            VStack {
                Chart {
                    ForEach(last30DaysLogs, id: \.self) { entry in
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
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    LogButtonView()
                }
                
                ToolbarItem {
                    QuickLogButton()
                }
            }
        }
    }
    
    func groupLogsByDate(logs: [LogEntry]) -> [Double] {
        let grouped = Dictionary(grouping: logs) { log in
            return log.timestamp.date
        }
        let summedLogs = grouped.mapValues { logs in
            logs.reduce(0) { $0 + $1.quantityInMG }
        }
        return summedLogs.values.sorted()
    }
}

struct ChartView_Previews: PreviewProvider {
    static var previews: some View {
        ChartView()
            .environmentObject(UserData())
    }
}
