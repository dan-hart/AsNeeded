//
//  SettingsView.swift
//  AsNeeded
//
//  Created by Dan Hart on 10/6/22.
//

import SwiftUI

struct SettingsView: View {
    @Binding var dose: Double
    
    var body: some View {
        VStack {
            Text("Dose")
                .font(.subheadline)
            Text("\(dose.formatted()) mg")
                .font(.largeTitle)
            HStack {
                Button {
                    dose -= 0.5
                } label: {
                    Text("-0.5")
                }
                
                Stepper("Dose", value: $dose, in: 0...Constants.maxQuantity)
                    .labelsHidden()
                
                Button {
                    dose += 0.5
                } label: {
                    Text("+0.5")
                }
            }
        }
        .padding()
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(dose: .constant(5))
    }
}
