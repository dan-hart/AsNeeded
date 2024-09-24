//
//  QuantityView.swift
//  AsNeeded
//
//  Created by Dan Hart on 10/6/22.
//

import SwiftUI
import SFSafeSymbols
import SwiftDate

struct QuantityView: View {
    @Binding var quantity: Double
    let here = Date()

    @StateObject var userData = UserData()
    
    var body: some View {
        VStack {
            Text("Quantity")
                .font(.subheadline)
            AsNeededMGView(value: $quantity)
            Text("updated \(userData.quantityLastUpdatedDate.toRelative(since: DateInRegion(year: here.year, month: here.month, day: here.day, hour: here.hour, minute: here.minute, second: here.second, nanosecond: here.nanosecond, region: here.region)))")
        }
        .padding()
    }
}

#if DEBUG
#Preview {
    QuantityView(quantity: .constant(90.0))
}
#endif
