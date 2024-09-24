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
            Logbook.shared.quickLog()
            userData.quantityInMG -= 1.0
            
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
        } label: {
            HStack {
            Image(systemSymbol: .pencilCircleFill)
                Text("Quick Log 1")
            }
        }
        .padding()
    }
}

#if DEBUG
#Preview {
    QuickLogButton()
        .environmentObject(UserData.preview)
}
#endif
