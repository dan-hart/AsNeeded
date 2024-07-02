//
//  AddOrSubtractQuantityView.swift
//  AsNeeded
//
//  Created by Dan Hart on 10/7/22.
//

import SwiftUI
import SFSafeSymbols

enum QuantityAdjustmentMode: String, CaseIterable {
    case set = "Set"
    case add = "Add"
    case subtract = "Subtract"
    
    var label: Label<Text, Image> {
        switch self {
        case .add:
            return Label(self.rawValue, systemSymbol: .plusCircleFill)
        case .subtract:
            return Label(self.rawValue, systemSymbol: .minusCircleFill)
        case .set:
            return Label(self.rawValue, systemSymbol: .plusCircleFill)
        }
    }
    
    func performAdjustment(fromInput: Double, on: Double) -> Double {
        switch self {
        case .add:
            return on + fromInput
        case .subtract:
            return on - fromInput
        case .set:
            return fromInput
        }
    }
}

struct AddOrSubtractQuantityView: View {
    @EnvironmentObject var userData: UserData
    
    @Binding var quantity: Double
    
    @State var input: String = ""
    @State var mode: QuantityAdjustmentMode = .set
    
    @FocusState private var isFocused: Bool
    
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        VStack {
            Picker("Mode", selection: $mode) {
                ForEach(QuantityAdjustmentMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            Text("\(mode.rawValue) Quantity")
                .font(.largeTitle)
            TextField("quantity in mg to \(mode.rawValue.lowercased())", text: $input, prompt: Text("quantity in mg to \(mode.rawValue.lowercased())"))
                .keyboardType(.numberPad)
                .focused($isFocused)
                .multilineTextAlignment(.center)
                .padding()
            Button {
                if let inputAsDouble = Double(input) {
                    quantity = mode.performAdjustment(fromInput: inputAsDouble, on: quantity)
                }
                presentationMode.wrappedValue.dismiss()
            } label: {
                mode.label
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

#Preview {
    AddOrSubtractQuantityView(quantity: .constant(150))
}
