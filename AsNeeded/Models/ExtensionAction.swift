//
//  ExtensionAction.swift
//  AsNeeded
//
//  Created by Dan Hart on 9/24/24.
//

import Foundation
import SwiftData

@Model
class ExtensionAction: Identifiable {
    var id: String
    var source: String
    var actionDescription: String
    var payload: String
    
    init(source: String, actionDescription: String, payload: String) {
        self.id = UUID().uuidString
        self.source = source
        self.actionDescription = actionDescription
        self.payload = payload
    }
}
