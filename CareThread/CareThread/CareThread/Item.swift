//
//  Item.swift
//  CareThread
//
//  Created by Gian Ramirez on 3/18/26.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
