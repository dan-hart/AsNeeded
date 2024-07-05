//
//  LogEntry+totalMG.swift
//  AsNeeded
//
//  Created by Dan Hart on 7/5/24.
//

import Foundation

extension [LogEntry] {
    /// The total quantity of medication in milligrams for all log entries in the array.
    var totalMG: Double {
        reduce(0) { $0 + $1.quantityInMG }
    }
}
