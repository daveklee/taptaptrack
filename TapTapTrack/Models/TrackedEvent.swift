//
//  TrackedEvent.swift
//  Tap Tap Track
//

import Foundation
import SwiftData
import SwiftUI

@Model
final class TrackedEvent {
    var id: UUID
    var timestamp: Date
    var notes: String?
    
    var preset: EventPreset?
    
    // Store denormalized data for history display even if preset is deleted
    var eventName: String
    var categoryName: String
    var iconName: String
    var colorHex: String?
    
    // Location data (optional, only for categories with location logging enabled)
    var latitude: Double?
    var longitude: Double?
    var locationName: String?
    var address: String?
    
    init(preset: EventPreset, notes: String? = nil, latitude: Double? = nil, longitude: Double? = nil, locationName: String? = nil, address: String? = nil) {
        self.id = UUID()
        self.timestamp = Date()
        self.notes = notes
        self.preset = preset
        
        // Denormalize for persistence
        self.eventName = preset.name
        self.categoryName = preset.category?.name ?? "Uncategorized"
        self.iconName = preset.iconName
        self.colorHex = preset.colorHex
        
        // Location data
        self.latitude = latitude
        self.longitude = longitude
        self.locationName = locationName
        self.address = address
    }
    
    var color: Color {
        if let colorHex = colorHex, !colorHex.isEmpty, let color = Color(hex: colorHex) {
            return color
        }
        // Fallback for existing events without colorHex
        return Color(hex: "#667eea") ?? .purple
    }
    
    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: timestamp)
    }
}

