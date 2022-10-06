//
//  QuantityView.swift
//  AsNeeded
//
//  Created by Dan Hart on 10/6/22.
//

import SwiftUI
import SFSafeSymbols

struct QuantityView: View {
    @Binding var quantity: Double
    
    var body: some View {
        VStack {
            Text("Quantity")
                .font(.subheadline)
            AsNeededMGView(value: $quantity)
        }
        .padding()
    }
}

struct QuantityView_Previews: PreviewProvider {
    static var previews: some View {
        QuantityView(quantity: .constant(90.0))
    }
}
