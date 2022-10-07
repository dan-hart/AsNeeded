//
//  RefillButtonView.swift
//  AsNeeded
//
//  Created by Dan Hart on 10/7/22.
//

import SwiftUI

struct RefillButtonView: View {
    @EnvironmentObject var userData: UserData
    
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        Button {
            userData.quantityInMG += userData.refillQuantityInMG
            presentationMode.wrappedValue.dismiss()
        } label: {
            Label("Refill", systemSymbol: .pillsCircleFill)
        }
    }
}

struct RefillButtonView_Previews: PreviewProvider {
    static var previews: some View {
        RefillButtonView()
    }
}
