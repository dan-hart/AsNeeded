//
//  UserData.swift
//  AsNeeded
//
//  Created by Dan Hart on 10/6/22.
//

import Foundation
import SwiftUI
import SwiftyUserDefaults
import SwiftDate

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
            
            daysRemainingUntilNextRefillDate = calculateDaysRemainingUntilNextRefillDate()
        }
    }
    
    @Published var dailyDoseInMG: Double {
        didSet {
            Defaults[\.dailyDoseInMG] = dailyDoseInMG
        }
    }
    
    @Published var plannedDailyDoseInMG: Double {
        didSet {
            Defaults[\.plannedDailyDoseInMG] = plannedDailyDoseInMG
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
    
    @Published var daysRemainingUntilNextRefillDate: Double?
    
    /// Returns the difference between now and the refill date.
    /// Add one because we count "Today" as a day, even if it is the end of the day
    func calculateDaysRemainingUntilNextRefillDate(from date: Date = .now) -> Double? {
        if nextRefillDate.isInPast { return nil }
        let timePeriod = TimePeriod(start: DateInRegion(year: date.year, month: date.month, day: date.day), end: DateInRegion(year: nextRefillDate.year, month: nextRefillDate.month, day: nextRefillDate.day))
        return Double(timePeriod.days)
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
        plannedDailyDoseInMG = Defaults[\.plannedDailyDoseInMG]
        
        daysRemainingUntilNextRefillDate = calculateDaysRemainingUntilNextRefillDate()
    }
}
