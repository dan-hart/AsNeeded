//
//  RefillButtonView.swift
//  AsNeeded
//
//  Created by Dan Hart on 10/7/22.
//

import SwiftUI

struct RefillButtonView: View {
    @EnvironmentObject var userData: UserData
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        Button {
            userData.quantityInMG += userData.refillQuantityInMG
            dismiss()
        } label: {
            Label("Refill", systemSymbol: .pillsCircleFill)
        }
    }
}

#if DEBUG
#Preview {
    RefillButtonView()
}
#endif
