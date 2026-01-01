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
        
        // CRITICAL: Schema Migration Safety
        // SwiftData automatically handles additive schema changes (adding new properties with defaults)
        // However, we must ensure:
        // 1. All new properties have default values (they do)
        // 2. Properties are accessed during migration to trigger initialization
        // 3. We never change existing property types (only add new ones)
        // 4. We verify data preservation before and after migration
        //
        // Schema evolution:
        // Version 1: Initial schema (Category, EventPreset, TrackedEvent)
        // Version 2: Added locationTrackingEnabled to Category, order to Category
        // Version 3: Added number input fields to EventPreset (numberEnabled, numberMin, etc.)
        // Version 4: Added locationTrackingEnabled to EventPreset
        //
        // All new properties use default values to ensure backward compatibility
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none
        )

        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            
            // Perform migration synchronously before returning container
            // This ensures all data is preserved when upgrading
            let context = container.mainContext
            
            // First, verify we can access the database and count existing data
            // This helps us detect if data was lost
            let categoryCount = (try? context.fetchCount(FetchDescriptor<Category>())) ?? 0
            let presetCount = (try? context.fetchCount(FetchDescriptor<EventPreset>())) ?? 0
            let eventCount = (try? context.fetchCount(FetchDescriptor<TrackedEvent>())) ?? 0
            
            print("Migration check: Found \(categoryCount) categories, \(presetCount) presets, \(eventCount) events")
            
            // If we have data, ensure it's preserved through migration
            if categoryCount > 0 || presetCount > 0 || eventCount > 0 {
                print("Existing data detected - ensuring safe migration")
            }
            
            // Check if we already have categories
            // Use do-catch to handle any migration errors gracefully
            let categoryDescriptor = FetchDescriptor<Category>(sortBy: [SortDescriptor(\.createdAt)])
            let existingCategories: [Category]?
            do {
                existingCategories = try context.fetch(categoryDescriptor)
                
                // Verify all categories have required properties initialized
                if let categories = existingCategories {
                    for category in categories {
                        // Access properties to ensure they're loaded and initialized
                        let _ = category.id
                        let _ = category.name
                        let _ = category.colorHex
                        let _ = category.createdAt
                        // These may be new properties - accessing them ensures defaults are applied
                        let _ = category.locationTrackingEnabled
                        let _ = category.order
                    }
                }
            } catch {
                // If fetch fails, it might indicate a migration issue
                // Log error but continue - SwiftData should handle migration automatically
                print("Warning: Failed to fetch categories during migration: \(error)")
                print("Error details: \(error.localizedDescription)")
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
                    
                    // Verify presets have new properties initialized
                    Self.ensurePresetPropertiesInitialized(context: context)
                    
                    // Save migration changes
                    do {
                        try context.save()
                        print("Migration completed successfully")
                    } catch {
                        print("Warning: Failed to save migration changes: \(error)")
                        // Don't fail - data is still in memory
                    }
                } else {
                    // Categories already have order set, but ensure locationTrackingEnabled is migrated
                    for category in categories {
                        let _ = category.locationTrackingEnabled
                    }
                    
                    // Migrate location tracking from category to preset level
                    // This migration runs for all existing data to move location tracking to preset level
                    Self.migrateLocationTrackingFromCategoryToPreset(context: context)
                    
                    // Verify presets have new properties initialized
                    Self.ensurePresetPropertiesInitialized(context: context)
                    
                    // Save to ensure migration is persisted
                    do {
                        try context.save()
                        print("Migration completed successfully")
                    } catch {
                        print("Warning: Failed to save migration changes: \(error)")
                        // Don't fail - data is still in memory
                    }
                }
                
                // Final verification - count data after migration
                let finalCategoryCount = (try? context.fetchCount(FetchDescriptor<Category>())) ?? 0
                let finalPresetCount = (try? context.fetchCount(FetchDescriptor<EventPreset>())) ?? 0
                let finalEventCount = (try? context.fetchCount(FetchDescriptor<TrackedEvent>())) ?? 0
                
                print("Post-migration: \(finalCategoryCount) categories, \(finalPresetCount) presets, \(finalEventCount) events")
                
                if finalCategoryCount != categoryCount || finalPresetCount != presetCount || finalEventCount != eventCount {
                    print("WARNING: Data count changed during migration!")
                    print("Before: \(categoryCount) categories, \(presetCount) presets, \(eventCount) events")
                    print("After: \(finalCategoryCount) categories, \(finalPresetCount) presets, \(finalEventCount) events")
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
            // CRITICAL: Never use fatalError for database issues - it prevents recovery
            // Log the error and attempt to create a new container
            // This allows the app to continue even if migration has issues
            print("ERROR: Failed to create ModelContainer: \(error)")
            print("Error details: \(error.localizedDescription)")
            
            // Attempt to create a minimal container as fallback
            // This ensures the app can still launch even if there's a schema issue
            do {
                let fallbackSchema = Schema([
                    Category.self,
                    EventPreset.self,
                    TrackedEvent.self,
                ])
                let fallbackConfig = ModelConfiguration(
                    schema: fallbackSchema,
                    isStoredInMemoryOnly: false,
                    cloudKitDatabase: .none
                )
                let fallbackContainer = try ModelContainer(for: fallbackSchema, configurations: [fallbackConfig])
                print("Created fallback container - app will continue but data may need to be restored")
                return fallbackContainer
            } catch {
                // Only use fatalError if we absolutely cannot create any container
                // This should never happen unless there's a fundamental system issue
                fatalError("CRITICAL: Could not create ModelContainer even with fallback. This indicates a system-level issue: \(error)")
            }
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
            print("Warning: Could not fetch presets for migration")
            return
        }
        
        print("Migrating location tracking for \(presets.count) presets")
        
        // For each preset, if it doesn't have locationTrackingEnabled set yet,
        // copy the value from its category (if the category has it enabled)
        var migratedCount = 0
        for preset in presets {
            // Ensure all properties are accessed to trigger initialization
            let _ = preset.id
            let _ = preset.name
            let _ = preset.iconName
            let _ = preset.colorHex
            let _ = preset.createdAt
            let _ = preset.numberEnabled
            let _ = preset.numberMin
            let _ = preset.numberMax
            let _ = preset.numberAllowDecimals
            let _ = preset.numberRequired
            
            // Access locationTrackingEnabled to ensure it's initialized
            let currentValue = preset.locationTrackingEnabled
            
            // Only migrate if preset doesn't already have location tracking configured
            // We check if locationTrackingEnabled is false AND the category has it enabled
            // This ensures we only migrate once and preserve any preset-level settings
            if !currentValue,
               let category = preset.category,
               category.locationTrackingEnabled {
                preset.locationTrackingEnabled = true
                migratedCount += 1
            }
        }
        
        print("Migrated location tracking for \(migratedCount) presets")
    }
    
    /// Ensures all preset properties are properly initialized with default values
    /// This is critical for preserving data during schema changes
    private static func ensurePresetPropertiesInitialized(context: ModelContext) {
        let presetDescriptor = FetchDescriptor<EventPreset>()
        guard let presets = try? context.fetch(presetDescriptor) else {
            return
        }
        
        for preset in presets {
            // Access all properties to ensure they're initialized
            // This is especially important for new properties with default values
            let _ = preset.locationTrackingEnabled
            let _ = preset.numberEnabled
            let _ = preset.numberMin
            let _ = preset.numberMax
            let _ = preset.numberAllowDecimals
            let _ = preset.numberRequired
        }
    }
}

