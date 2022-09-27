//
//  HealthDataAccessing.swift
//  AsNeeded
//
//  Created by Dan Hart on 9/26/22.
//

import Foundation

protocol HealthDataAccessing {
    var isAvailable: Bool { get }
    
    func requestClinicalMedicationPermission() async -> Bool
}
