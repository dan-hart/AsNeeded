//
//  AsNeededDatePickerView.swift
//  AsNeeded
//
//  Created by Dan Hart on 10/6/22.
//

import SwiftUI
import SwiftDate
import SFSafeSymbols

struct AsNeededDatePickerView: View {
    @Binding var nextRefillDate: Date
    
    var body: some View {
        VStack {
            HStack {
                Button {
                    nextRefillDate = nextRefillDate.dateByAdding(-30, .day).date
                } label: {
                    Text("-30")
                }
                
                Spacer()
                
                Button {
                    nextRefillDate = nextRefillDate.dateByAdding(-1, .day).date
                } label: {
                    Image(systemSymbol: .minusCircleFill)
                }

                DatePicker(selection: $nextRefillDate, in: ...Date.distantFuture, displayedComponents: .date) {
                    Text("Next Refill Date")
                }
                
                Button {
                    nextRefillDate = nextRefillDate.dateByAdding(1, .day).date
                } label: {
                    Image(systemSymbol: .plusCircleFill)
                }
                
                Spacer()
                
                Button {
                    nextRefillDate = nextRefillDate.dateByAdding(30, .day).date
                } label: {
                    Text("+30")
                }
            }
            .labelsHidden()
            
            Button {
                nextRefillDate = .now
            } label: {
                Text("Today")
            }
        }
    }
}

struct AsNeededDatePickerView_Previews: PreviewProvider {
    static var previews: some View {
        AsNeededDatePickerView(nextRefillDate: .constant(.now))
    }
}
