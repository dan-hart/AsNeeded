//
//  ContentView.swift
//  AsNeeded
//
//  Created by Dan Hart on 10/6/22.
//

import SwiftUI
import SwiftyUserDefaults
import SFSafeSymbols

struct ContentView: View {
    @State var showSettings = false
    @ObservedObject var userData = UserData()
    
    var body: some View {
        NavigationStack {
            VStack {
                AsNeededDatePickerView(nextRefillDate: $userData.nextRefillDate)
                Text("\(userData.daysRemainingUntilNextRefillDate?.formatted() ?? "No") \("day".pluralize(count: Int(userData.daysRemainingUntilNextRefillDate ?? -1))) remaining")
                    .font(.largeTitle)
                QuantityView(quantity: $userData.quantity)
            }
            .toolbar {
                ToolbarItem {
                    Button {
                        showSettings.toggle()
                    } label: {
                        Image(systemSymbol: .gearCircle)
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView(dose: $userData.dailyDoseInMG)
            }
            
            .navigationTitle("AsNeeded")
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
