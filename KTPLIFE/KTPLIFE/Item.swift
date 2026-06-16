//
//  Item.swift
//  KTPLIFE
//
//  Created by Seyi Babatunde on 6/16/26.
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
