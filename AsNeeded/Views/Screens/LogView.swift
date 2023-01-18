//
//  LogView.swift
//  AsNeeded
//
//  Created by Dan Hart on 1/17/23.
//

import SwiftUI
import RealmSwift

struct LogView: View {
    @State var input = ""
    @State var timestamp = Date.now
    @FocusState private var isFocused: Bool
    @Environment(\.presentationMode) var presentationMode
    
    @EnvironmentObject var userData: UserData
    
    var body: some View {
        VStack {
            Button {
                Logbook.quickLog()
                userData.quantityInMG -= 1.0
                presentationMode.wrappedValue.dismiss()
            } label: {
                Label("Quick Log 1", systemSymbol: .pencilCircleFill)
            }
            .padding()
            
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
                Logbook.log(quantityInMG: quantityInMG, at: self.timestamp)
                userData.quantityInMG -= quantityInMG
                
                presentationMode.wrappedValue.dismiss()
            } label: {
                Label("Submit Log", systemSymbol: .pencilCircleFill)
            }
        }
        .onAppear {
            isFocused = true
        }
    }
}

struct LogView_Previews: PreviewProvider {
    static var previews: some View {
        LogView()
    }
}
