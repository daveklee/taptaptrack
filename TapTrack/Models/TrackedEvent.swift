//
//  TrackedEvent.swift
//  Tap Tap Track
//

import Foundation
import SwiftData

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
    
    init(preset: EventPreset, notes: String? = nil) {
        self.id = UUID()
        self.timestamp = Date()
        self.notes = notes
        self.preset = preset
        
        // Denormalize for persistence
        self.eventName = preset.name
        self.categoryName = preset.category?.name ?? "Uncategorized"
        self.iconName = preset.iconName
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

