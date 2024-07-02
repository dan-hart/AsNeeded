//
//  AsNeededMGView.swift
//  AsNeeded
//
//  Created by Dan Hart on 10/6/22.
//

import SwiftUI

struct AsNeededMGView: View {
    @EnvironmentObject var userData: UserData
    
    @Binding var value: Double
    var minimumValue: Double = 0
    
    @State var showAddQuantity = false
    
    var body: some View {
        VStack {
            Text("\(value.formatted()) mg")
                .font(.largeTitle)
                .onTapGesture {
                    showAddQuantity.toggle()
                }
            HStack {
                Button {
                    value -= 0.5
                } label: {
                    Text("-0.5")
                }
                
                Spacer()
                
                Stepper("", value: $value, in: minimumValue...Constants.maxQuantity)
                    .labelsHidden()
                
                Spacer()
                
                Button {
                    value += 0.5
                } label: {
                    Text("+0.5")
                }
            }
        }
        .onChange(of: value, { _, _ in
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
        })
        .sheet(isPresented: $showAddQuantity) {
            AddOrSubtractQuantityView(quantity: $value)
                .presentationDetents([.fraction(0.4), .fraction(0.50)])
        }
    }
}

#Preview {
    AsNeededMGView(value: .constant(0.5))
        .environmentObject(UserData.preview)
}
