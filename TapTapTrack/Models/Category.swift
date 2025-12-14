//
//  Category.swift
//  Tap Tap Track
//

import Foundation
import SwiftData
import SwiftUI

@Model
final class Category {
    var id: UUID
    var name: String
    var colorHex: String
    var createdAt: Date
    var locationTrackingEnabled: Bool = false
    var order: Int = 0
    
    @Relationship(deleteRule: .cascade, inverse: \EventPreset.category)
    var presets: [EventPreset]?
    
    init(name: String, colorHex: String = "#6366F1", locationTrackingEnabled: Bool = false, order: Int = 0) {
        self.id = UUID()
        self.name = name
        self.colorHex = colorHex
        self.createdAt = Date()
        self.locationTrackingEnabled = locationTrackingEnabled
        self.order = order
    }
    
    var color: Color {
        Color(hex: colorHex) ?? .purple
    }
}

// MARK: - Color Extension
extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt64 = 0
        
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else {
            return nil
        }
        
        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0
        
        self.init(red: r, green: g, blue: b)
    }
}

