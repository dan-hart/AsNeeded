//
//  AsNeededDatePickerView.swift
//  AsNeeded
//
//  Created by Dan Hart on 10/6/22.
//

import SwiftUI

struct AsNeededDatePickerView: View {
    @Binding var nextRefillDate: Date
    
    var body: some View {
        VStack {
            Text("Next Refill Date")
                .font(.subheadline)
            DatePicker(selection: $nextRefillDate, in: ...Date.distantFuture, displayedComponents: .date) {
                Text("Next Refill Date")
            }
            .labelsHidden()
        }
    }
}

struct AsNeededDatePickerView_Previews: PreviewProvider {
    static var previews: some View {
        AsNeededDatePickerView(nextRefillDate: .constant(.now))
    }
}
