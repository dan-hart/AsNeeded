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
    
    @EnvironmentObject var userData: UserData
    
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

struct QuantityView_Previews: PreviewProvider {
    static var previews: some View {
        QuantityView(quantity: .constant(90.0))
    }
}
