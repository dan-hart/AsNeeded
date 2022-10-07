//
//  DefaultKeys.swift
//  AsNeeded
//
//  Created by Dan Hart on 10/6/22.
//

import Foundation
import SwiftyUserDefaults

extension DefaultsKeys {
    var quantity: DefaultsKey<Double> { .init("quantity", defaultValue: 0.0) }
    var quantityLastUpdatedDate: DefaultsKey<Date> { .init("quantityLastUpdatedDate", defaultValue: .now) }
    var nextRefillDate: DefaultsKey<Date> { .init("nextRefillDate", defaultValue: .now) }
    var dailyDoseInMG: DefaultsKey<Double> { .init("dailyDoseInMG", defaultValue: 1) }
    var plannedDailyDoseInMG: DefaultsKey<Double> { .init("plannedDailyDoseInMG", defaultValue: 1) }
    var refillQuantityInMG: DefaultsKey<Double> { .init("refillQuantityInMG", defaultValue: 50) }
    var aheadTrajectoryInMG: DefaultsKey<Double> { .init("aheadTrajectoryInMG", defaultValue: 1) }
}
