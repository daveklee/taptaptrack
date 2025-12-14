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
            
            // Seed initial data if needed and handle migration
            Task { @MainActor in
                let context = container.mainContext
                
                // Check if we already have categories
                let categoryDescriptor = FetchDescriptor<Category>(sortBy: [SortDescriptor(\.createdAt)])
                let existingCategories = try? context.fetch(categoryDescriptor)
                
                // Access existing categories to ensure migration completes properly
                // The default value (= false) should handle migration automatically
                if let categories = existingCategories, !categories.isEmpty {
                    // Just accessing the property ensures it's initialized with default value
                    var needsOrderUpdate = false
                    // Check if all categories have order 0 (indicating they need migration)
                    let allHaveDefaultOrder = categories.allSatisfy { $0.order == 0 }
                    
                    if allHaveDefaultOrder {
                        // Set order based on createdAt (they're already sorted by createdAt)
                        for (index, category) in categories.enumerated() {
                            let _ = category.locationTrackingEnabled
                            category.order = index
                            needsOrderUpdate = true
                        }
                    } else {
                        // Just ensure locationTrackingEnabled is accessed for migration
                        for category in categories {
                            let _ = category.locationTrackingEnabled
                        }
                    }
                    
                    if needsOrderUpdate {
                        try? context.save()
                    }
                }
                
                if existingCategories?.isEmpty ?? true {
                    // Seed categories with explicit order
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

