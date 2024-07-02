//
//  TrajectoryView.swift
//  AsNeeded
//
//  Created by Dan Hart on 10/6/22.
//

import SwiftUI

struct TrajectoryView: View {
    var value: Trajectory
    
    var body: some View {
        Text(value.rawValue)
            .foregroundColor(getTextColor(for: value))
            .font(.largeTitle)
            .padding()
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(getBackgroundColor(for: value), lineWidth: 1)
            )
            .background(RoundedRectangle(cornerRadius: 20)
                .fill(getBackgroundColor(for: value)))
    }
    
    func getTextColor(for value: Trajectory) -> Color {
        switch value {
        case .ahead, .onTrack, .danger, .unknown:
            return .white
        case .behind, .slowDown:
            return .black
        }
    }
    
    func getBackgroundColor(for value: Trajectory) -> Color {
        switch value {
        case .ahead:
            return .mint
        case .onTrack:
            return .green
        case .behind, .slowDown:
            return .yellow
        case .danger:
            return .red
        case .unknown:
            return Color.accentColor
        }
    }
}

#Preview {
    Group {
        ForEach(Trajectory.allCases, id: \.self) { t in
            TrajectoryView(value: t)
        }
    }
}
