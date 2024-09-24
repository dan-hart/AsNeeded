//
//  RefillButtonView.swift
//  AsNeeded
//
//  Created by Dan Hart on 10/7/22.
//

import SwiftUI

struct RefillButtonView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject var logbook: Logbook = .shared
    
    var body: some View {
        Button {
            logbook.user.quantityInMG += logbook.user.refillQuantityInMG
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
