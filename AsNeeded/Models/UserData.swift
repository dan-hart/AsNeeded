//
//  UserData.swift
//  AsNeeded
//
//  Created by Dan Hart on 10/6/22.
//

import Foundation
import SwiftUI
import SwiftyUserDefaults

class UserData: ObservableObject {
    @Published var quantity: Double {
        didSet {
            Defaults[\.quantity] = quantity
        }
    }
    
    @Published var nextRefillDate: Date {
        didSet {
            Defaults[\.nextRefillDate] = nextRefillDate
        }
    }
    
    @Published var dailyDoseInMG: Double {
        didSet {
            Defaults[\.dailyDoseInMG] = dailyDoseInMG
        }
    }
    
    /// Returns the difference between now and the refill date.
    /// Add one because we count "Today" as a day, even if it is the end of the day
    var daysRemainingUntilNextRefillDate: Double? {
        let now = Date()
        if nextRefillDate.isInPast { return nil }
        guard let differenceDate = now.difference(in: .day, from: nextRefillDate) else { return nil }
        return Double(differenceDate.days.day ?? -1) + 1 // See property documentation
    }
    
    init() {
        quantity = Defaults[\.quantity]
        nextRefillDate = Defaults[\.nextRefillDate]
        dailyDoseInMG = Defaults[\.dailyDoseInMG]
    }
}
