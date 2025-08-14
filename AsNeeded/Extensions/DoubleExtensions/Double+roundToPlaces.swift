//
//  Double+roundToPlaces.swift
//  AsNeeded
//
//  Created by Dan Hart on 10/6/22.
//

import Foundation

extension Double {
    /// Rounds the double to decimal places value
    func rounded(toPlaces places: Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
}
