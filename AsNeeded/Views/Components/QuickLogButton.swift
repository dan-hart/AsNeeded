//
//  QuickLogButton.swift
//  AsNeeded
//
//  Created by Dan Hart on 7/7/23.
//

import SwiftUI

struct QuickLogButton: View {
    @EnvironmentObject var userData: UserData
    
    var body: some View {
        Button {
            Logbook.quickLog()
            userData.quantityInMG -= 1.0
        } label: {
            Label("Quick Log 1", systemSymbol: .pencilCircleFill)
        }
        .padding()
    }
}

struct QuickLogButton_Previews: PreviewProvider {
    static var previews: some View {
        QuickLogButton()
    }
}
