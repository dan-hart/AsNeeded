//
//  ContentView.swift
//  AsNeeded
//
//  Created by Dan Hart on 10/6/22.
//

import SwiftUI
import SwiftyUserDefaults

struct ContentView: View {
    @ObservedObject var userData = UserData()
    
    var body: some View {
        NavigationStack {
            VStack {
                AsNeededDatePickerView(nextRefillDate: $userData.nextRefillDate)
                Text("\(userData.daysRemainingUntilNextRefillDate?.formatted() ?? "[Error]") days remaining")
                    .font(.largeTitle)
                QuantityView(quantity: $userData.quantity)
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
