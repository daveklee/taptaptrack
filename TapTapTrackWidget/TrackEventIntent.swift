//
//  TrackEventIntent.swift
//  TapTapTrack Widget
//
//  NOTE: The widget uses Links for buttons, not App Intents.
//  This file only contains EventPresetEntity for WidgetConfigurationIntent.
//  The main App Intent is in TapTapTrack/TrackEventIntent.swift

import AppIntents
import SwiftData
import Foundation

// EventPresetEntity must match exactly with the one in TapTapTrack/TrackEventIntent.swift
// This is used by WidgetConfigurationIntent for widget configuration
@available(iOS 17.0, *)
struct EventPresetEntity: AppEntity, Identifiable, Codable {
    var id: UUID
    
    static var typeDisplayRepresentation: TypeDisplayRepresentation = TypeDisplayRepresentation(name: "Event Preset")
    static var defaultQuery = EventPresetQuery()
    
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: LocalizedStringResource(stringLiteral: name.isEmpty ? "Unknown Event" : name),
            subtitle: LocalizedStringResource(stringLiteral: categoryName.isEmpty ? "Uncategorized" : categoryName),
            image: DisplayRepresentation.Image(systemName: iconName.isEmpty ? "star.fill" : iconName)
        )
    }
    
    var name: String
    var iconName: String
    var colorHex: String?
    var categoryName: String
    
    init(id: UUID, name: String = "", iconName: String = "star.fill", colorHex: String? = nil, categoryName: String = "Uncategorized") {
        self.id = id
        self.name = name
        self.iconName = iconName
        self.colorHex = colorHex
        self.categoryName = categoryName
    }
    
    // Codable implementation for AppEntity
    enum CodingKeys: String, CodingKey {
        case id, name, iconName, colorHex, categoryName
    }
}

@available(iOS 17.0, *)
struct EventPresetQuery: EntityQuery {
    @MainActor
    func entities(for identifiers: [EventPresetEntity.ID]) async throws -> [EventPresetEntity] {
        guard !identifiers.isEmpty else { return [] }
        
        do {
            let schema = Schema([
                Category.self,
                EventPreset.self,
            ])
            let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            let context = container.mainContext
            
            let descriptor = FetchDescriptor<EventPreset>()
            let allPresets = try context.fetch(descriptor)
            
            let matchingPresets = allPresets.filter { identifiers.contains($0.id) }
            
            if !matchingPresets.isEmpty {
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
            
            return identifiers.map { id in
                EventPresetEntity(id: id, name: "Unknown Event", iconName: "star.fill", categoryName: "Uncategorized")
            }
        } catch {
            print("EventPresetQuery.entities error: \(error.localizedDescription)")
            return identifiers.map { id in
                EventPresetEntity(id: id, name: "Unknown Event", iconName: "star.fill", categoryName: "Uncategorized")
            }
        }
    }
    
    @MainActor
    func suggestedEntities() async throws -> [EventPresetEntity] {
        do {
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
            
            return Array(presets.prefix(20)).map { preset in
                EventPresetEntity(
                    id: preset.id,
                    name: preset.name,
                    iconName: preset.iconName,
                    colorHex: preset.colorHex,
                    categoryName: preset.category?.name ?? "Uncategorized"
                )
            }
        } catch {
            print("EventPresetQuery.suggestedEntities error: \(error.localizedDescription)")
            return []
        }
    }
}

