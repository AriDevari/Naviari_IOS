//
//  Item.swift
//  Naviari_IOS
//
//  Created by Ari Peltoniemi on 4.2.2026.
//

import Foundation
import SwiftData

/// Placeholder SwiftData entity kept for Xcode template compatibility; not used by the race flow.
@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
