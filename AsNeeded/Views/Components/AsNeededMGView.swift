//
//  AsNeededMGView.swift
//  AsNeeded
//
//  Created by Dan Hart on 10/6/22.
//

import SwiftUI

struct AsNeededMGView: View {
    @Binding var value: Double
    var minimumValue: Double = 0
    
    var body: some View {
        VStack {
            Text("\(value.formatted()) mg")
                .font(.largeTitle)
            HStack {
                Button {
                    value -= 0.5
                } label: {
                    Text("-0.5")
                }
                
                Stepper("", value: $value, in: minimumValue...Constants.maxQuantity)
                    .labelsHidden()
                
                Button {
                    value += 0.5
                } label: {
                    Text("+0.5")
                }
            }
        }
    }
}

struct AsNeededMGView_Previews: PreviewProvider {
    static var previews: some View {
        AsNeededMGView(value: .constant(0.5))
    }
}
