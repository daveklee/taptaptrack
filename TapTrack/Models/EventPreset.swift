//
//  EventPreset.swift
//  Tap Tap Track
//

import Foundation
import SwiftData

@Model
final class EventPreset {
    var id: UUID
    var name: String
    var iconName: String
    var createdAt: Date
    
    var category: Category?
    
    @Relationship(deleteRule: .cascade, inverse: \TrackedEvent.preset)
    var trackedEvents: [TrackedEvent]?
    
    init(name: String, iconName: String = "star.fill", category: Category? = nil) {
        self.id = UUID()
        self.name = name
        self.iconName = iconName
        self.createdAt = Date()
        self.category = category
    }
}

// MARK: - Available Icons
extension EventPreset {
    static let availableIcons: [(name: String, systemName: String)] = [
        ("People", "person.3.fill"),
        ("Exercise", "figure.strengthtraining.traditional"),
        ("Coffee", "cup.and.saucer.fill"),
        ("Phone", "phone.fill"),
        ("Sleep", "bed.double.fill"),
        ("Food", "fork.knife"),
        ("Heart", "heart.fill"),
        ("Star", "star.fill"),
        ("Book", "book.fill"),
        ("Music", "music.note"),
        ("Car", "car.fill"),
        ("Home", "house.fill"),
        ("Medical", "cross.fill"),
        ("Shopping", "bag.fill"),
        ("Calendar", "calendar"),
    ]
}

