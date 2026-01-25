//
//  TrackEventIntent.swift
//  Tap Tap Track
//
//  App Intent for tracking events from Shortcuts

import AppIntents
import SwiftData
import Foundation

@available(iOS 17.0, *)
struct TrackEventIntent: AppIntent {
    static var title: LocalizedStringResource = "Track Event"
    static var description = IntentDescription("Track an event and open the app to confirm details")
    static var openAppWhenRun: Bool = true
    static var isDiscoverable: Bool = true
    static var parameterSummary: some ParameterSummary {
        Summary("Track \(\.$preset)")
    }
    
    @Parameter(title: "Event Preset", description: "The event preset to track")
    var preset: EventPresetEntity
    
    init() {}
    
    init(preset: EventPresetEntity) {
        self.preset = preset
    }
    
    @MainActor
    func perform() async throws -> some IntentResult {
        print("TrackEventIntent.perform() called")
        
        print("TrackEventIntent: Preset received - ID: \(preset.id), Name: \(preset.name)")
        
        // Validate that we have a preset with a valid ID
        let presetIDString = preset.id.uuidString
        guard !presetIDString.isEmpty, presetIDString != "00000000-0000-0000-0000-000000000000" else {
            print("TrackEventIntent: Invalid preset ID: \(presetIDString)")
            throw IntentError.presetNotFound
        }
        
        // Store the preset ID in UserDefaults for the app to retrieve
        // This approach works reliably for Shortcuts
        guard let userDefaults = UserDefaults(suiteName: "group.com.taptaptrack") else {
            print("TrackEventIntent: Failed to access App Group UserDefaults")
            throw IntentError.saveFailed
        }
        
        // Store both the preset ID and metadata for debugging
        userDefaults.set(presetIDString, forKey: "pendingPresetID")
        if !preset.name.isEmpty {
            userDefaults.set(preset.name, forKey: "pendingPresetName")
        }
        
        // Synchronize immediately - this is critical for Shortcuts
        let syncResult = userDefaults.synchronize()
        print("TrackEventIntent: UserDefaults sync result: \(syncResult)")
        
        print("TrackEventIntent: Successfully stored preset ID: \(presetIDString), name: \(preset.name)")
        
        // The app will handle creating the event when it opens
        print("TrackEventIntent: Returning success result")
        return .result()
    }
}

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
        print("EventPresetQuery.entities called with identifiers: \(identifiers)")
        guard !identifiers.isEmpty else { 
            print("EventPresetQuery.entities: Empty identifiers, returning empty array")
            return [] 
        }
        
        do {
            // Use the same ModelContainer configuration as the app
            let schema = Schema([
                Category.self,
                EventPreset.self,
            ])
            let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            let context = container.mainContext
            
            // Fetch all presets and filter by identifiers
            let descriptor = FetchDescriptor<EventPreset>()
            let allPresets = try context.fetch(descriptor)
            
            let matchingPresets = allPresets.filter { identifiers.contains($0.id) }
            
            // If we found matching presets, return them
            if !matchingPresets.isEmpty {
                print("EventPresetQuery.entities: Found \(matchingPresets.count) matching presets")
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
            
            // If no matching presets found, return entities with just the IDs
            // This allows the intent to still work even if the preset was deleted
            print("EventPresetQuery: No matching presets found for identifiers: \(identifiers), returning fallback entities")
            return identifiers.map { id in
                EventPresetEntity(id: id, name: "Unknown Event", iconName: "star.fill", categoryName: "Uncategorized")
            }
        } catch {
            // If we can't access SwiftData, return entities with just the IDs
            // This allows Shortcuts to still work even if data isn't available
            print("EventPresetQuery.entities error: \(error.localizedDescription), returning fallback entities")
            // Return fallback entities so the intent can still work
            return identifiers.map { id in
                EventPresetEntity(id: id, name: "Unknown Event", iconName: "star.fill", categoryName: "Uncategorized")
            }
        }
    }
    
    @MainActor
    func suggestedEntities() async throws -> [EventPresetEntity] {
        print("EventPresetQuery.suggestedEntities called")
        
        do {
            print("EventPresetQuery.suggestedEntities: Attempting to access SwiftData")
            // Use the same ModelContainer configuration as the app
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
            
            print("EventPresetQuery.suggestedEntities: Found \(presets.count) presets, returning first 20")
            
            // Return up to 20 presets for better discoverability in Shortcuts
            let entities = Array(presets.prefix(20)).map { preset in
                EventPresetEntity(
                    id: preset.id,
                    name: preset.name,
                    iconName: preset.iconName,
                    colorHex: preset.colorHex,
                    categoryName: preset.category?.name ?? "Uncategorized"
                )
            }
            print("EventPresetQuery.suggestedEntities: Returning \(entities.count) entities")
            return entities
        } catch {
            // If we can't access SwiftData, log the error but return empty array
            // This allows Shortcuts to still show the action (even if presets aren't listed)
            print("EventPresetQuery.suggestedEntities error: \(error.localizedDescription), returning empty array")
            // Return empty array instead of throwing - this allows the intent to still be discoverable
            return []
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

