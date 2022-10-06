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
    @Published var quantityInMG: Double {
        didSet {
            Defaults[\.quantity] = quantityInMG
            quantityLastUpdatedDate = .now
        }
    }
    
    @Published var quantityLastUpdatedDate: Date {
        didSet {
            Defaults[\.quantityLastUpdatedDate] = quantityLastUpdatedDate
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
    
    @Published var aheadTrajectoryInMG: Double {
        didSet {
            Defaults[\.aheadTrajectoryInMG] = aheadTrajectoryInMG
        }
    }
    
    @Published var refillQuantityInMG: Double {
        didSet {
            Defaults[\.refillQuantityInMG] = refillQuantityInMG
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
    
    // MARK: - Calculations
    
    /// How many MGs are available per day until the next refill date
    var dailyAvailableInMG: Double? {
        if let daysRemainingUntilNextRefillDate {
            return quantityInMG / daysRemainingUntilNextRefillDate
        } else { return nil }
    }
    
    /// Subtract the daily available from the dose
    var dailyTrimInMG: Double? {
        if let dailyAvailableInMG {
            return dailyAvailableInMG - dailyDoseInMG
        } else { return nil }
    }
    
    var currentStatus: Trajectory {
        Trajectory.calculate(forDailyTrimInMG: dailyTrimInMG)
    }
    
    // MARK: - Formatting
    var dailyAvailable: String {
        let dailyAvailable: String? = "\(dailyAvailableInMG?.rounded(toPlaces: 2) ?? -Constants.maxQuantity)"
        if dailyAvailable == "-\(Constants.maxQuantity)" {
            return ""
        }
        return "\(dailyAvailable ?? "No") mg available per day"
    }
    
    var dailyTrim: String {
        let dailyTrim: String? = "\(dailyTrimInMG?.rounded(toPlaces: 2) ?? -Constants.maxQuantity)"
        if dailyTrim == "-\(Constants.maxQuantity)" {
            return ""
        }
        return "\(dailyTrim ?? "No") daily difference from dose"
    }
    
    init() {
        quantityInMG = Defaults[\.quantity]
        quantityLastUpdatedDate = Defaults[\.quantityLastUpdatedDate]
        nextRefillDate = Defaults[\.nextRefillDate]
        dailyDoseInMG = Defaults[\.dailyDoseInMG]
        aheadTrajectoryInMG = Defaults[\.aheadTrajectoryInMG]
        refillQuantityInMG = Defaults[\.refillQuantityInMG]
    }
}
