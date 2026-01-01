//
//  TapTapTrackApp.swift
//  Tap Tap Track
//
//  Created for tracking life events with style
//  https://taptaptrack.com
//

import SwiftUI
import SwiftData
import AppIntents

@main
struct TapTapTrackApp: App {
    @State private var pendingEventID: UUID?
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Category.self,
            EventPreset.self,
            TrackedEvent.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            
            // Perform migration synchronously before returning container
            // This ensures categories are preserved when upgrading from version 1.0
            let context = container.mainContext
            
            // Check if we already have categories
            // Use do-catch to handle any migration errors gracefully
            let categoryDescriptor = FetchDescriptor<Category>(sortBy: [SortDescriptor(\.createdAt)])
            let existingCategories: [Category]?
            do {
                existingCategories = try context.fetch(categoryDescriptor)
            } catch {
                // If fetch fails, it might indicate a migration issue
                // Log error but continue - SwiftData should handle migration automatically
                print("Warning: Failed to fetch categories during migration: \(error)")
                existingCategories = nil
            }
            
            if let categories = existingCategories, !categories.isEmpty {
                // Migrate existing categories from version 1.0 to current version
                // Ensure locationTrackingEnabled and order properties are properly initialized
                
                // Check if all categories have order 0, which indicates migration from 1.0 is needed
                // (Categories from 1.0 won't have the order property, so they'll default to 0)
                let allHaveDefaultOrder = categories.allSatisfy { $0.order == 0 }
                
                if allHaveDefaultOrder {
                    // Migrating from version 1.0: set order based on creation date
                    // Categories are already sorted by createdAt, so we can assign sequential order
                    for (index, category) in categories.enumerated() {
                        // Access locationTrackingEnabled to ensure SwiftData migration completes
                        // This triggers the property to be initialized with default value (false)
                        let _ = category.locationTrackingEnabled
                        
                        // Set order based on creation date (they're already sorted)
                        category.order = index
                    }
                    
                    // Migrate location tracking from category to preset level
                    Self.migrateLocationTrackingFromCategoryToPreset(context: context)
                    
                    // Save migration changes
                    try? context.save()
                } else {
                    // Categories already have order set, but ensure locationTrackingEnabled is migrated
                    for category in categories {
                        let _ = category.locationTrackingEnabled
                    }
                    
                    // Migrate location tracking from category to preset level
                    // This migration runs for all existing data to move location tracking to preset level
                    Self.migrateLocationTrackingFromCategoryToPreset(context: context)
                    
                    // Save to ensure migration is persisted
                    try? context.save()
                }
            } else {
                // No existing categories - seed initial data
                let work = Category(name: "Work", colorHex: "#6366F1", locationTrackingEnabled: false, order: 0)
                let personal = Category(name: "Personal", colorHex: "#8B5CF6", locationTrackingEnabled: false, order: 1)
                let health = Category(name: "Health", colorHex: "#EC4899", locationTrackingEnabled: false, order: 2)
                let social = Category(name: "Social", colorHex: "#14B8A6", locationTrackingEnabled: false, order: 3)
                
                context.insert(work)
                context.insert(personal)
                context.insert(health)
                context.insert(social)
                
                // Seed event presets
                let cityPreset = EventPreset(name: "City", iconName: "person.3.fill", category: work)
                let exercisePreset = EventPreset(name: "Exercise", iconName: "figure.strengthtraining.traditional", category: health)
                let coffeePreset = EventPreset(name: "Coffee Break", iconName: "cup.and.saucer.fill", category: personal)
                let eventPreset = EventPreset(name: "Event", iconName: "phone.fill", category: work)
                let sleepPreset = EventPreset(name: "Sleep", iconName: "bed.double.fill", category: health)
                
                context.insert(cityPreset)
                context.insert(exercisePreset)
                context.insert(coffeePreset)
                context.insert(eventPreset)
                context.insert(sleepPreset)
                
                try? context.save()
            }
            
            return container
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView(pendingEventID: $pendingEventID)
                .onOpenURL { url in
                    handleDeepLink(url: url)
                }
                .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { userActivity in
                    if let url = userActivity.webpageURL {
                        handleDeepLink(url: url)
                    }
                }
                .onAppear {
                    // Check for pending event from widget
                    let userDefaults = UserDefaults(suiteName: "group.com.taptaptrack")
                    userDefaults?.synchronize() // Ensure we have latest data
                    
                    if let eventIDString = userDefaults?.string(forKey: "pendingEventID"),
                       let eventID = UUID(uuidString: eventIDString) {
                        pendingEventID = eventID
                        // Clear the stored ID
                        userDefaults?.removeObject(forKey: "pendingEventID")
                        userDefaults?.synchronize()
                    }
                    
                    // Also check for pending preset ID immediately
                    checkForPendingPresetID()
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                    // Check again when app becomes active (handles cold start)
                    checkForPendingPresetID()
                }
        }
        .modelContainer(sharedModelContainer)
    }
    
    private func handleDeepLink(url: URL) {
        // Handle deep link from widget
        // Format: taptaptrack://track/{presetID}
        if url.scheme == "taptaptrack" && url.host == "track" {
            let pathComponents = url.pathComponents.filter { $0 != "/" }
            if let presetIDString = pathComponents.first,
               let presetID = UUID(uuidString: presetIDString) {
                // Store preset ID - TrackView will handle creating the event
                let userDefaults = UserDefaults(suiteName: "group.com.taptaptrack")
                userDefaults?.set(presetID.uuidString, forKey: "pendingPresetID")
                userDefaults?.synchronize()
                
                // Post notification to switch to Track tab
                NotificationCenter.default.post(name: NSNotification.Name("SwitchToTrackTab"), object: nil)
                
                // Also trigger immediate check
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    checkForPendingPresetID()
                }
            }
        }
    }
    
    private func checkForPendingPresetID() {
        let userDefaults = UserDefaults(suiteName: "group.com.taptaptrack")
        userDefaults?.synchronize()
        
        if let presetIDString = userDefaults?.string(forKey: "pendingPresetID"),
           let presetID = UUID(uuidString: presetIDString) {
            // Create the event immediately using the shared model container
            let context = sharedModelContainer.mainContext
            let descriptor = FetchDescriptor<EventPreset>(
                predicate: #Predicate<EventPreset> { $0.id == presetID }
            )
            
            if let preset = try? context.fetch(descriptor).first {
                let event = TrackedEvent(preset: preset)
                context.insert(event)
                try? context.save()
                
                // Set the pending event ID to show confirmation
                pendingEventID = event.id
                
                // Clear the stored preset ID
                userDefaults?.removeObject(forKey: "pendingPresetID")
                userDefaults?.synchronize()
            }
        }
    }
    
    /// Migrates location tracking configuration from category level to preset level
    /// This ensures that existing users don't lose their location tracking settings
    private static func migrateLocationTrackingFromCategoryToPreset(context: ModelContext) {
        // Fetch all presets
        let presetDescriptor = FetchDescriptor<EventPreset>()
        guard let presets = try? context.fetch(presetDescriptor) else {
            return
        }
        
        // For each preset, if it doesn't have locationTrackingEnabled set yet,
        // copy the value from its category (if the category has it enabled)
        for preset in presets {
            // Only migrate if preset doesn't already have location tracking configured
            // We check if locationTrackingEnabled is false AND the category has it enabled
            // This ensures we only migrate once and preserve any preset-level settings
            if !preset.locationTrackingEnabled,
               let category = preset.category,
               category.locationTrackingEnabled {
                preset.locationTrackingEnabled = true
            }
        }
    }
}

