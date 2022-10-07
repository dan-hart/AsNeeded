//
//  AddOrSubtractQuantityView.swift
//  AsNeeded
//
//  Created by Dan Hart on 10/7/22.
//

import SwiftUI
import SFSafeSymbols

struct AddOrSubtractQuantityView: View {
    @EnvironmentObject var userData: UserData
    
    @Binding var quantity: Double
    
    @State var input: String = ""
    @State var mode = "Add"
    
    @FocusState private var isFocused: Bool
    
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        VStack {
            Picker("Mode", selection: $mode) {
                Text("Add").tag("Add")
                Text("Subtract").tag("Subtract")
            }
            .pickerStyle(.segmented)

            Text("\(mode) Quantity")
                .font(.largeTitle)
            TextField("quantity in mg to \(mode.lowercased())", text: $input, prompt: Text("quantity in mg to \(mode.lowercased())"))
                .keyboardType(.numberPad)
                .focused($isFocused)
                .multilineTextAlignment(.center)
                .padding()
            Button {
                if let inputAsDouble = Double(input) {
                    if mode == "Add" {
                        quantity += inputAsDouble
                    } else {
                        quantity -= inputAsDouble
                    }
                }
                presentationMode.wrappedValue.dismiss()
            } label: {
                if mode == "Add" {
                    Label("Add", systemSymbol: .plusCircleFill)
                } else {
                    Label("Subtract", systemSymbol: .minusCircleFill)
                }
            }
            
            RefillButtonView()
                .padding()
        }
        .onAppear {
            isFocused = true
        }
        .padding()
    }
}

struct AddQuantityView_Previews: PreviewProvider {
    static var previews: some View {
        AddOrSubtractQuantityView(quantity: .constant(150))
    }
}
