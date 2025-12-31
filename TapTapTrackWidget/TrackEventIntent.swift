//
//  TrackEventIntent.swift
//  TapTapTrack Widget
//
//  App Intent for tracking events from the widget

import AppIntents
import SwiftData
import Foundation

@available(iOS 17.0, *)
struct TrackEventIntent: AppIntent {
    static var title: LocalizedStringResource = "Track Event"
    static var description = IntentDescription("Track an event from the widget")
    static var openAppWhenRun: Bool = true
    static var isDiscoverable: Bool = true
    
    @Parameter(title: "Event Preset")
    var preset: EventPresetEntity
    
    init() {}
    
    init(preset: EventPresetEntity) {
        self.preset = preset
    }
    
    @MainActor
    func perform() async throws -> some IntentResult {
        // Instead of accessing SwiftData from the widget (which can fail),
        // store the preset ID and let the app handle the event creation
        // This is more reliable and avoids SwiftData access issues in widget extensions
        
        // Store the preset ID in UserDefaults for the app to retrieve
        let userDefaults = UserDefaults(suiteName: "group.com.taptaptrack")
        userDefaults?.set(preset.id.uuidString, forKey: "pendingPresetID")
        userDefaults?.synchronize()
        
        // The app will handle creating the event when it opens
        // This approach is more reliable than trying to access SwiftData from the widget
        
        return .result()
    }
}

@available(iOS 17.0, *)
struct EventPresetEntity: AppEntity {
    var id: UUID
    
    static var typeDisplayRepresentation: TypeDisplayRepresentation = TypeDisplayRepresentation(name: "Event Preset")
    static var defaultQuery = EventPresetQuery()
    
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: LocalizedStringResource(stringLiteral: name),
            subtitle: LocalizedStringResource(stringLiteral: categoryName),
            image: DisplayRepresentation.Image(systemName: iconName)
        )
    }
    
    var name: String
    var iconName: String
    var colorHex: String?
    var categoryName: String
    
    init(id: UUID, name: String, iconName: String, colorHex: String?, categoryName: String) {
        self.id = id
        self.name = name
        self.iconName = iconName
        self.colorHex = colorHex
        self.categoryName = categoryName
    }
}

@available(iOS 17.0, *)
struct EventPresetQuery: EntityQuery {
    @MainActor
    func entities(for identifiers: [EventPresetEntity.ID]) async throws -> [EventPresetEntity] {
        let schema = Schema([
            Category.self,
            EventPreset.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
        let context = container.mainContext
        
        // Fetch all presets and filter by identifiers (since contains() doesn't work in predicates)
        let descriptor = FetchDescriptor<EventPreset>()
        let allPresets = try context.fetch(descriptor)
        
        let matchingPresets = allPresets.filter { identifiers.contains($0.id) }
        
        return matchingPresets.map { preset in
            EventPresetEntity(
                id: preset.id,
                name: preset.name,
                iconName: preset.iconName,
                colorHex: preset.colorHex,
                categoryName: preset.category?.name ?? "Uncategorized"
            )
        }
    }
    
    @MainActor
    func suggestedEntities() async throws -> [EventPresetEntity] {
        let schema = Schema([
            Category.self,
            EventPreset.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
        let context = container.mainContext
        
        let descriptor = FetchDescriptor<EventPreset>(
            sortBy: [SortDescriptor(\.category?.order), SortDescriptor(\.createdAt)]
        )
        
        let presets = try context.fetch(descriptor)
        
        // Return up to 8 most recently used or all if less than 8
        return Array(presets.prefix(8)).map { preset in
            EventPresetEntity(
                id: preset.id,
                name: preset.name,
                iconName: preset.iconName,
                colorHex: preset.colorHex,
                categoryName: preset.category?.name ?? "Uncategorized"
            )
        }
    }
}

enum IntentError: Error, CustomLocalizedStringResourceConvertible {
    case presetNotFound
    case saveFailed
    
    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .presetNotFound:
            return "Event preset not found"
        case .saveFailed:
            return "Failed to save event"
        }
    }
}

