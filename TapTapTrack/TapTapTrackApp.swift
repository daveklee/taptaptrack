//
//  TapTapTrackApp.swift
//  Tap Tap Track
//
//  Created for tracking life events with style
//  https://taptaptrack.com
//

import SwiftUI
import SwiftData

@main
struct TapTapTrackApp: App {
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
                    
                    // Save migration changes
                    try? context.save()
                } else {
                    // Categories already have order set, but ensure locationTrackingEnabled is migrated
                    for category in categories {
                        let _ = category.locationTrackingEnabled
                    }
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
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}

