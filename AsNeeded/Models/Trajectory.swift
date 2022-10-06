//
//  Trajectory.swift
//  AsNeeded
//
//  Created by Dan Hart on 10/6/22.
//

import Foundation

enum Trajectory: String, CaseIterable {
    case ahead = "Ahead"
    case onTrack = "On Track"
    case behind = "Behind"
    case danger = "Danger"
}
