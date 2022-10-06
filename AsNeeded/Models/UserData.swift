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
    
    init() {
        quantity = Defaults[\.quantity]
        nextRefillDate = Defaults[\.nextRefillDate]
    }
}
