//
//  LogButtonView.swift
//  AsNeeded
//
//  Created by Dan Hart on 1/17/23.
//

import SwiftUI

struct LogButtonView: View {
    @EnvironmentObject var userData: UserData
    
    @State var isShowingLogView = false
    var body: some View {
        Button {
            isShowingLogView.toggle()
        } label: {
            Label("Log", systemSymbol: .plusCircleFill)
        }
        .sheet(isPresented: $isShowingLogView) {
            LogView().presentationDetents([.medium])
                .environmentObject(userData)
        }
    }
}

#Preview {
    LogButtonView(isShowingLogView: false)
}
