//
//  LogItem+totalMG.swift
//  AsNeeded
//
//  Created by Dan Hart on 7/5/24.
//

import Foundation

extension [LogItem] {
    /// The total quantity of medication in milligrams for all log entries in the array.
    var totalMG: Double {
        reduce(0) { $0 + $1.quantityInMG }
    }
    
    var roundedTotalMG: String {
        let result = "\(totalMG.rounded(toPlaces: 1))"
        if result.hasSuffix(".0") {
            return String(result.dropLast(2))
        } else {
            return result
        }
    }
}
