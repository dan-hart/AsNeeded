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
            #if os(iOS)
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
            #endif
            
            Logbook.shared.quickLog()
        } label: {
            HStack {
                #if os(iOS)
            Image(systemSymbol: .pencilCircleFill)
                Text("Quick Log 1")
                #else
                Text("Quick Log 1")
                #endif
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
