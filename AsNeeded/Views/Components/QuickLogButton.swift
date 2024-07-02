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
            HStack {
            Image(systemSymbol: .pencilCircleFill)
                Text("Quick Log 1")
            }
        }
        .padding()
    }
}

#Preview {
    QuickLogButton()
        .environmentObject(UserData.preview)
}
