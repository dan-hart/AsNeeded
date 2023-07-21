//
//  TrendView.swift
//  AsNeeded
//
//  Created by Dan Hart on 7/21/23.
//

import SwiftUI

struct TrendView: View {
    var trend: TrendAnalyzer.Trend
    
    var body: some View {
        Text(trend.description)
            .font(.title)
            .padding()
            .background(trend.color)
            .cornerRadius(10)
            .foregroundColor(.white)
    }
}

struct TrendView_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            TrendView(trend: .down)
            TrendView(trend: .up)
            TrendView(trend: .stable)
        }
    }
}
