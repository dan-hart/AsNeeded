//
//  User.swift
//  AsNeeded
//
//  Created by Dan Hart on 9/24/24.
//

import Foundation
import SwiftData
#if os(iOS)
import SwiftDate
import SwiftyUserDefaults
#endif

@Model
class User: Identifiable, Hashable, Equatable {
    var id: String = UUID().uuidString
    var quantityInMG: Double = 0 {
        didSet {
            quantityLastUpdated = .now
        }
    }
    var quantityLastUpdated: Date = Date()
    var nextRefillDate: Date = Date()
    var dailyDoseInMG: Double = 0
    var aheadTrajectoryInMG: Double = 0
    var plannedDailyDoseInMG: Double = 0
    var refillQuantityInMG: Double = 0
    
    init(quantityInMG: Double, quantityLastUpdated: Date, nextRefillDate: Date, dailyDoseInMG: Double, aheadTrajectoryInMG: Double, plannedDailyDoseInMG: Double, refillQuantityInMG: Double) {
        self.quantityInMG = quantityInMG
        self.quantityLastUpdated = quantityLastUpdated
        self.nextRefillDate = nextRefillDate
        self.dailyDoseInMG = dailyDoseInMG
        self.aheadTrajectoryInMG = aheadTrajectoryInMG
        self.plannedDailyDoseInMG = plannedDailyDoseInMG
        self.refillQuantityInMG = refillQuantityInMG
    }
    
//    init() {
//        self.quantityInMG = 0
//        self.quantityLastUpdated = .now
//        self.nextRefillDate = .now
//        self.dailyDoseInMG = 0
//        self.aheadTrajectoryInMG = 0
//        self.plannedDailyDoseInMG = 0
//        self.refillQuantityInMG = 0
//    }
    
    init() {
        #if os(iOS)
        quantityInMG = Defaults[\.quantity]
        quantityLastUpdated = Defaults[\.quantityLastUpdatedDate]
        nextRefillDate = Defaults[\.nextRefillDate]
        dailyDoseInMG = Defaults[\.dailyDoseInMG]
        aheadTrajectoryInMG = Defaults[\.aheadTrajectoryInMG]
        refillQuantityInMG = Defaults[\.refillQuantityInMG]
        plannedDailyDoseInMG = Defaults[\.plannedDailyDoseInMG]
        #endif
    }
    
    /// The number of days remaining until the next refill date.
    /// - Parameter date: The date to calculate from. Defaults to the current date.
    /// - Returns: The number of days remaining until the next refill date.
    func calculateDaysRemainingUntilNextRefillDate(from date: Date = .now) -> Double {
        #if os(iOS)
        let components = date.differences(in: [.day], from: nextRefillDate)
        return Double(components[.day] ?? 0)
        #else
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: date, to: nextRefillDate)
        return Double(components.day ?? 0)
        #endif
    }
    
    // MARK: - Calculations
    
    var daysRemainingUntilNextRefillDate: Double {
        calculateDaysRemainingUntilNextRefillDate()
    }
    
    /// How many MGs are available per day until the next refill date
    var dailyAvailableInMG: Double {
        let daysRemaining = calculateDaysRemainingUntilNextRefillDate()
        return daysRemaining > 0 ? (quantityInMG / daysRemaining) : 0
    }
    
    /// Subtract the daily available from the dose
    var dailyTrimInMG: Double {
        return dailyAvailableInMG - dailyDoseInMG
    }
    
    var currentStatus: TrendAnalyzer.ConsumptionStatus {
        return .ahead // TODO: Implement
    }
    
    // MARK: - Formatting
    var dailyAvailable: String {
        let dailyAvailable: String? = "\(dailyAvailableInMG.rounded(toPlaces: 2))"
        return "\(dailyAvailable ?? "No") mg available per day"
    }
    
    var dailyTrim: String {
        let dailyTrim: String? = "\(dailyTrimInMG.rounded(toPlaces: 2))"
        return "\(dailyTrim ?? "No") daily difference from dose"
    }
}

#if DEBUG
extension User {
    static let preview: User = {
        let user = User()
        user.quantityInMG = 150
        user.dailyDoseInMG = 5
        #if os(iOS)
        user.nextRefillDate = .now + 7.days
        #else
        user.nextRefillDate = Date() + 7 * 24 * 60 * 60
        #endif
        user.plannedDailyDoseInMG = 3
        user.refillQuantityInMG = 150
        return user
    }()
}
#endif

