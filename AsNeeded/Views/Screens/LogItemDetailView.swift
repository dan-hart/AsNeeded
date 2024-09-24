//
//  LogItemDetailView.swift
//  AsNeeded
//
//  Created by Dan Hart on 9/23/24.
//

import SwiftUI
import SwiftData

struct LogItemDetailView: View {
    @EnvironmentObject var userData: UserData
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) var dismiss
    var logItem: LogItem
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("\(logItem.roundedQuantityInMG) MG")
                .font(.title)
            
            Text("\(logItem.timestamp, style: .date) at \(logItem.timestamp, style: .time)")
                .font(.subheadline)
            
            Spacer()
                .frame(height: 50)
            
            Button {
                modelContext.delete(logItem)
                userData.quantityInMG += logItem.quantityInMG
                if modelContext.hasChanges {
                    try? modelContext.save()
                }
                dismiss()
            } label: {
                Label("Delete", systemSymbol: .trash)
                    .foregroundStyle(.red)
            }
        }
        .padding()
        .navigationTitle("Log Item Details")
    }
}

#if DEBUG
#Preview {
    LogItemDetailView(logItem: LogItem.preview())
}
#endif
