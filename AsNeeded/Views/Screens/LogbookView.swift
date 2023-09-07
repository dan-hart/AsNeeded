//
//  LogbookView.swift
//  AsNeeded
//
//  Created by Dan Hart on 1/17/23.
//

import SwiftUI
import RealmSwift

struct LogbookView: View {
    @ObservedResults(LogEntry.self) var logs
    
    private let sortDescriptors = [
        SortDescriptor(keyPath: "timestamp", ascending: false)
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack {
                    ForEach(logs.sorted(by: sortDescriptors), id: \.self) { log in
                        LogEntryRowView(log: log)
                    }
                }
                .navigationTitle("Logbook")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        LogButtonView()
                    }
                    
                    ToolbarItem {
                        QuickLogButton()
                    }
                }
                .padding()
            }
        }
    }
}

struct LogbookView_Previews: PreviewProvider {
    static var previews: some View {
        LogbookView()
    }
}
