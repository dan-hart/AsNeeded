//
//  QuickLogButton.swift
//  AsNeeded
//
//  Created by Dan Hart on 7/7/23.
//

import SwiftUI

struct QuickLogButton: View {
    var body: some View {
        Button {
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
            
            Logbook.shared.quickLog()
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
}
#endif
