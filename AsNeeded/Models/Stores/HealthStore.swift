//
//  HealthStore.swift
//  AsNeeded
//
//  Created by Dan Hart on 8/14/25.
//

import HealthKit

/// A reference to the shared `HKHealthStore` for views to use.
final class HealthStore: Sendable {

    static let shared: HealthStore = HealthStore()

    let healthStore = HKHealthStore()

    private init() { }

}
