//
//  TapTrackApp.swift
//  Tap Tap Track
//
//  Created for tracking life events with style
//  https://taptaptrack.com
//

import SwiftUI
import SwiftData

@main
struct TapTrackApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Category.self,
            EventPreset.self,
            TrackedEvent.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            
            // Seed initial data if needed
            Task { @MainActor in
                let context = container.mainContext
                
                // Check if we already have categories
                let categoryDescriptor = FetchDescriptor<Category>()
                let existingCategories = try? context.fetch(categoryDescriptor)
                
                if existingCategories?.isEmpty ?? true {
                    // Seed categories
                    let work = Category(name: "Work", colorHex: "#6366F1")
                    let personal = Category(name: "Personal", colorHex: "#8B5CF6")
                    let health = Category(name: "Health", colorHex: "#EC4899")
                    let social = Category(name: "Social", colorHex: "#14B8A6")
                    
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

