//
//  DisclaimerView.swift
//  AsNeeded
//
//  Created by Dan Hart on 10/6/22.
//

import SwiftUI

struct DisclaimerView: View {
    var body: some View {
        VStack(alignment: .leading) {
            Text("Disclaimer")
                .foregroundColor(.white)
                .font(.title2)
                .padding([.top, .leading, .trailing])
            Text("This beta app is not designed to replace real medical advice. Do not take any action without first consulting a licensed physician.")
                .foregroundColor(.white)
                .font(.footnote)
                .padding([.bottom, .leading, .trailing])
        }
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.accentColor, lineWidth: 1)
        )
        .background(RoundedRectangle(cornerRadius: 20)
            .fill(Color.accentColor))
        .padding()
    }
}

struct DisclaimerView_Previews: PreviewProvider {
    static var previews: some View {
        DisclaimerView()
    }
}
