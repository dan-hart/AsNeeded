//
//  LogView.swift
//  AsNeeded
//
//  Created by Dan Hart on 1/17/23.
//

import SwiftUI

struct LogView: View {
    @State var input = ""
    @State var timestamp = Date.now
    @FocusState var isFocused: Bool
    @Environment(\.presentationMode) var presentationMode
    
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack {
            QuickLogButton()
            
            Text("Log")
                .font(.largeTitle)
            DatePicker("Timestamp", selection: $timestamp, displayedComponents: [.date, .hourAndMinute])
                .labelsHidden()
                .padding()
            TextField("Quantity in MG to Log", text: $input, prompt: Text("Quantity in MG to Log"))
                .keyboardType(.numberPad)
                .focused($isFocused)
                .multilineTextAlignment(.center)
                .padding()
            Button {
                guard let quantityInMG = Double(self.input) else { return }
                Logbook.shared.log(quantityInMG: quantityInMG, at: self.timestamp)
                
                dismiss()
            } label: {
                Label("Submit Log", systemSymbol: .pencilCircleFill)
            }
        }
        .onAppear {
            isFocused = true
        }
    }
}

#if DEBUG
#Preview {
    LogView()
}
#endif
