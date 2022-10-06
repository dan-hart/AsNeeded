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
    var nextRefillDate: DefaultsKey<Date> { .init("nextRefillDate", defaultValue: .now) }
    var dailyDoseInMG: DefaultsKey<Double> { .init("dailyDoseInMG", defaultValue: 1) }
}
