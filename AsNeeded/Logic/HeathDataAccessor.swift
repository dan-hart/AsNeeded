//
//  HeathDataAccessor.swift
//  AsNeeded
//
//  Created by Dan Hart on 9/26/22.
//

import Foundation
import HealthKit

class HealthDataAccessor: HealthDataAccessing {
    static var shared: HealthDataAccessing = HealthDataAccessor()
    let store = HKHealthStore()
    
    // MARK: - Permissions
    var isAvailable: Bool {
        return HKHealthStore.isHealthDataAvailable()
    }
    
    func requestClinicalMedicationPermission() async -> Bool {
        guard let medicationRecords = HKObjectType.clinicalType(forIdentifier: .medicationRecord) else {
            return false
        }
        
        return await requestClinical(types: [medicationRecords])
    }
    
    func requestClinical(types: Set<HKClinicalType>) async -> Bool {
        let success = try? await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Bool, Error>) in
            // Clinical types are read-only.
            store.requestAuthorization(toShare: nil, read: types) { (success, error) in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: success)
            }
        }
        return success ?? false
    }
}
