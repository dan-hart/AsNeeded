//
//  Trajectory.swift
//  AsNeeded
//
//  Created by Dan Hart on 10/6/22.
//

import Foundation
import SwiftyUserDefaults

enum Trajectory: String, CaseIterable {
    case ahead = "Ahead"
    case onTrack = "On Track"
    case slowDown = "Slow Down"
    case behind = "Behind"
    case danger = "Danger"
    case unknown = "Unknown"
    
    static func calculate(forDailyTrimInMG value: Double?) -> Trajectory {
        guard let value else { return .unknown }
        
        // Determine current status based on daily trim
        let aheadTrajectoryInMG = Defaults[\.aheadTrajectoryInMG]
        if value >= aheadTrajectoryInMG {
            return .ahead
        } else if value >= 0 {
            return .onTrack
        } else if value < 0, value >= Constants.behindThreshold {
            return .slowDown
        } else if value < 0, value >= Constants.dangerThreshold {
            return .behind
        } else if value <= Constants.dangerThreshold {
            return .danger
        } else {
            return .unknown
        }
    }
}
