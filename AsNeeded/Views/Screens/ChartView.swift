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
    
    var last30DaysQuantity: [Double] {
        last30DaysLogs.map { entry in
            entry.quantityInMG
        }
    }
    
    var last7DaysQuantity: [Double] {
        last30DaysQuantity.suffix(7)
    }
    
    @State var yMax = 7
    
    var body: some View {
        NavigationStack {
            VStack {
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
}

struct ChartView_Previews: PreviewProvider {
    static var previews: some View {
        ChartView()
    }
}
