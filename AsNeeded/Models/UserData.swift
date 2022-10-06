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
    
    var daysRemainingUntilNextRefillDate: Double? {
        let now = Date()
        if nextRefillDate.isInPast { return nil }
        guard let differenceDate = now.difference(in: .day, from: nextRefillDate) else { return nil }
        return Double(differenceDate.days.day ?? -1)
    }
    
    init() {
        quantity = Defaults[\.quantity]
        nextRefillDate = Defaults[\.nextRefillDate]
    }
}
