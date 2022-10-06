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
        VStack {
            AsNeededDatePickerView(nextRefillDate: $userData.nextRefillDate)
            QuantityView(quantity: $userData.quantity)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
