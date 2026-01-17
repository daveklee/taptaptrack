//
//  ManageView.swift
//  Tap Tap Track
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import UIKit

private enum ManageSheet: Identifiable {
    case addCategory
    case editCategory(Category)
    case addPreset
    case editPreset(EventPreset)
    case about
    case foursquareHelp
    
    var id: String {
        switch self {
        case .addCategory:
            return "addCategory"
        case .editCategory(let category):
            return "editCategory-\(category.id.uuidString)"
        case .addPreset:
            return "addPreset"
        case .editPreset(let preset):
            return "editPreset-\(preset.id.uuidString)"
        case .about:
            return "about"
        case .foursquareHelp:
            return "foursquareHelp"
        }
    }
}

private struct PresetDeleteContext {
    let id: UUID
    let name: String
    let eventCount: Int
}

private struct CategoryDeleteContext {
    let id: UUID
    let name: String
    let presetCount: Int
    let eventCount: Int
}

struct ManageView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Category.order) private var categories: [Category]
    @Query(sort: \EventPreset.createdAt) private var presets: [EventPreset]
    
    @State private var activeSheet: ManageSheet?
    @State private var presetDeleteContext: PresetDeleteContext?
    @State private var categoryDeleteContext: CategoryDeleteContext?
    @State private var showingPresetDeleteConfirmation = false
    @State private var showingCategoryDeleteConfirmation = false
    @State private var isImporting: Bool = false
    @State private var showingFileImporter: Bool = false
    @State private var showingFoursquareImporter: Bool = false
    @State private var importResult: ImportResult?
    @State private var showingDocumentPicker: Bool = false

    private var editableCategories: [Category] {
        categories.filter { !$0.isHiddenCategory }
    }
    
    var body: some View {
        ZStack {
            // Dark background
            Color(hex: "#0f0f1a")!
                .ignoresSafeArea()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Title
                    Text("Manage")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.top, 60)
                    
                    // Categories Section
                    CategoriesSection(
                        categories: editableCategories,
                        onAdd: { activeSheet = .addCategory },
                        onEdit: { category in
                            // Store category directly - same pattern as presets
                            activeSheet = .editCategory(category)
                        },
                        onDelete: { category in
                            categoryDeleteContext = makeCategoryDeleteContext(for: category)
                            showingCategoryDeleteConfirmation = true
                        },
                        onMove: reorderCategories
                    )
                    
                    // Event Presets Section
                    PresetsSection(
                        presets: presets,
                        onAdd: { activeSheet = .addPreset },
                        onEdit: { preset in
                            activeSheet = .editPreset(preset)
                        },
                        onDelete: { preset in
                            presetDeleteContext = makePresetDeleteContext(for: preset)
                            showingPresetDeleteConfirmation = true
                        }
                    )
                    
                    // About & Help Section
                    AboutSection(onTap: { activeSheet = .about })
                    
                    // Import Section
                    ImportSection(
                        isImporting: isImporting,
                        onCSVImport: {
                            hapticFeedback()
                            // Use document picker (more reliable than fileImporter)
                            showingDocumentPicker = true
                        },
                        onFoursquareImport: { 
                            // Workaround for SwiftUI fileImporter not showing after dismissal
                            if showingFoursquareImporter {
                                showingFoursquareImporter = false
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                    showingFoursquareImporter = true
                                }
                            } else {
                                showingFoursquareImporter = true
                            }
                        },
                        onFoursquareHelp: { activeSheet = .foursquareHelp }
                    )
                    
                    Spacer(minLength: 100)
                }
            }
            
            // Floating Action Button
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    FloatingActionButton {
                        activeSheet = .addPreset
                    }
                    .padding(.trailing, 20)
                    .padding(.bottom, 100)
                }
            }
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .addCategory:
                AddCategorySheet { name in
                    addCategory(name: name)
                }
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
            case .editCategory(let category):
                EditCategorySheet(category: category) { name in
                    updateCategory(category, name: name)
                }
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
            case .addPreset:
                AddPresetSheet(categories: categories) { name, iconName, colorHex, category, numberEnabled, numberMin, numberMax, numberAllowDecimals, numberRequired, locationTrackingEnabled in
                    addPreset(name: name, iconName: iconName, colorHex: colorHex, category: category, numberEnabled: numberEnabled, numberMin: numberMin, numberMax: numberMax, numberAllowDecimals: numberAllowDecimals, numberRequired: numberRequired, locationTrackingEnabled: locationTrackingEnabled)
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            case .editPreset(let preset):
                EditPresetSheet(preset: preset, categories: categories) { name, iconName, colorHex, category, numberEnabled, numberMin, numberMax, numberAllowDecimals, numberRequired, locationTrackingEnabled in
                    updatePreset(preset, name: name, iconName: iconName, colorHex: colorHex, category: category, numberEnabled: numberEnabled, numberMin: numberMin, numberMax: numberMax, numberAllowDecimals: numberAllowDecimals, numberRequired: numberRequired, locationTrackingEnabled: locationTrackingEnabled)
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            case .about:
                AboutSheet()
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            case .foursquareHelp:
                FoursquareImportHelpSheet()
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
        }
        .fileImporter(
            isPresented: $showingFileImporter,
            allowedContentTypes: [.commaSeparatedText, .text, .plainText],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    // Accept files with .csv extension or if it's not a directory
                    let fileExtension = url.pathExtension.lowercased()
                    if fileExtension == "csv" || (!url.hasDirectoryPath && fileExtension.isEmpty) {
                        importFromCSV(url: url)
                    } else {
                        importResult = ImportResult(success: false, message: "Please select a CSV file (.csv extension).", importedCount: 0)
                    }
                } else {
                    importResult = ImportResult(success: false, message: "No file was selected.", importedCount: 0)
                }
            case .failure(let error):
                importResult = ImportResult(success: false, message: "Failed to select file: \(error.localizedDescription)", importedCount: 0)
            }
        }
        .fileImporter(
            isPresented: $showingFoursquareImporter,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    importFromFoursquare(url: url)
                }
            case .failure(let error):
                importResult = ImportResult(success: false, message: "Failed to select file: \(error.localizedDescription)", importedCount: 0)
            }
        }
        .alert(item: $importResult) { result in
            Alert(
                title: Text(result.success ? "Import Successful" : "Import Failed"),
                message: Text(result.message),
                dismissButton: .default(Text("OK"))
            )
        }
        .background(
            DocumentPickerPresenter(
                isPresented: $showingDocumentPicker,
                allowedContentTypes: [.commaSeparatedText, .text, .plainText],
                onDocumentPicked: { selectedURL in
                    importFromCSV(url: selectedURL)
                },
                onCancel: {
                    // User cancelled, do nothing
                }
            )
        )
        .confirmationDialog(
            "Delete preset?",
            isPresented: $showingPresetDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Preset & All Events", role: .destructive) {
                if let context = presetDeleteContext {
                    deletePresetAndEvents(id: context.id)
                }
                presetDeleteContext = nil
                showingPresetDeleteConfirmation = false
            }
            
            Button("Delete Preset Only", role: .destructive) {
                if let context = presetDeleteContext {
                    deletePresetKeepEvents(id: context.id)
                }
                presetDeleteContext = nil
                showingPresetDeleteConfirmation = false
            }
            
            Button("Cancel", role: .cancel) {
                presetDeleteContext = nil
                showingPresetDeleteConfirmation = false
            }
        } message: {
            presetDeleteMessage()
        }
        .confirmationDialog(
            "Delete category?",
            isPresented: $showingCategoryDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Category", role: .destructive) {
                if let context = categoryDeleteContext {
                    deleteCategory(id: context.id)
                }
                categoryDeleteContext = nil
                showingCategoryDeleteConfirmation = false
            }
            
            Button("Cancel", role: .cancel) {
                categoryDeleteContext = nil
                showingCategoryDeleteConfirmation = false
            }
        } message: {
            categoryDeleteMessage()
        }
    }
    
    private func addCategory(name: String) {
        // Set order to be after the last category
        let maxOrder = categories.map { $0.order }.max() ?? -1
        let category = Category(name: name, locationTrackingEnabled: false, order: maxOrder + 1)
        modelContext.insert(category)
        hapticFeedback()
    }
    
    private func deleteCategory(_ category: Category) {
        modelContext.delete(category)
        hapticFeedback()
    }
    
    private func deleteCategory(id: UUID) {
        let descriptor = FetchDescriptor<Category>(predicate: #Predicate { $0.id == id })
        if let category = try? modelContext.fetch(descriptor).first {
            deleteCategory(category)
        }
    }
    
    private func updateCategory(_ category: Category, name: String) {
        category.name = name
        // Note: locationTrackingEnabled is kept on Category for backward compatibility
        // but is no longer used - location logging is now at the preset level
        hapticFeedback()
    }
    
    private func presetDeleteMessage() -> Text {
        guard let context = presetDeleteContext else {
            return Text("This will remove the preset.")
        }
        
        let eventCount = context.eventCount
        if eventCount > 0 {
            return Text("\"\(context.name)\" has \(eventCount) tracked event\(eventCount == 1 ? "" : "s"). You can delete everything, or keep the events and only remove the preset.")
        }
        
        return Text("This will remove \"\(context.name)\". No tracked events are associated with it.")
    }
    
    private func categoryDeleteMessage() -> Text {
        guard let context = categoryDeleteContext else {
            return Text("This will permanently delete the category and all associated data. This action cannot be undone.")
        }
        
        let presetCount = context.presetCount
        let eventCount = context.eventCount
        
        if presetCount > 0 || eventCount > 0 {
            var parts: [String] = []
            if presetCount > 0 {
                parts.append("all \(presetCount) preset\(presetCount == 1 ? "" : "s")")
            }
            if eventCount > 0 {
                parts.append("all \(eventCount) tracked event\(eventCount == 1 ? "" : "s")")
            }
            
            let itemsList = parts.joined(separator: " and ")
            return Text("This will permanently delete the category \"\(context.name)\", \(itemsList), and all associated data. This action cannot be undone.")
        }
        
        return Text("This will permanently delete the category \"\(context.name)\". No presets or events are associated with it.")
    }
    
    private func makePresetDeleteContext(for preset: EventPreset) -> PresetDeleteContext {
        PresetDeleteContext(
            id: preset.id,
            name: preset.name,
            eventCount: preset.trackedEvents?.count ?? 0
        )
    }
    
    private func makeCategoryDeleteContext(for category: Category) -> CategoryDeleteContext {
        var eventCount = 0
        if let presets = category.presets {
            for preset in presets {
                eventCount += preset.trackedEvents?.count ?? 0
            }
        }
        
        return CategoryDeleteContext(
            id: category.id,
            name: category.name,
            presetCount: category.presets?.count ?? 0,
            eventCount: eventCount
        )
    }
    
    private func addPreset(name: String, iconName: String, colorHex: String, category: Category?, numberEnabled: Bool = false, numberMin: Double? = nil, numberMax: Double? = nil, numberAllowDecimals: Bool = false, numberRequired: Bool = false, locationTrackingEnabled: Bool = false) {
        let preset = EventPreset(name: name, iconName: iconName, colorHex: colorHex, category: category, numberEnabled: numberEnabled, numberMin: numberMin, numberMax: numberMax, numberAllowDecimals: numberAllowDecimals, numberRequired: numberRequired, locationTrackingEnabled: locationTrackingEnabled)
        modelContext.insert(preset)
        hapticFeedback()
    }
    
    private func updatePreset(_ preset: EventPreset, name: String, iconName: String, colorHex: String, category: Category?, numberEnabled: Bool = false, numberMin: Double? = nil, numberMax: Double? = nil, numberAllowDecimals: Bool = false, numberRequired: Bool = false, locationTrackingEnabled: Bool = false) {
        preset.name = name
        preset.iconName = iconName
        preset.colorHex = colorHex
        preset.category = category
        preset.numberEnabled = numberEnabled
        preset.numberMin = numberMin
        preset.numberMax = numberMax
        preset.numberAllowDecimals = numberAllowDecimals
        preset.numberRequired = numberRequired
        preset.locationTrackingEnabled = locationTrackingEnabled
        hapticFeedback()
    }
    
    private func deletePreset(_ preset: EventPreset) {
        modelContext.delete(preset)
        hapticFeedback()
    }
    
    private func deletePresetAndEvents(_ preset: EventPreset) {
        // The cascade delete rule will automatically delete all associated events
        modelContext.delete(preset)
        hapticFeedback()
    }
    
    private func deletePresetAndEvents(id: UUID) {
        let descriptor = FetchDescriptor<EventPreset>(predicate: #Predicate { $0.id == id })
        if let preset = try? modelContext.fetch(descriptor).first {
            deletePresetAndEvents(preset)
        }
    }
    
    private func deletePresetKeepEvents(_ preset: EventPreset) {
        // Unlink all tracked events from this preset before deleting
        // The events will retain their denormalized data (eventName, categoryName, iconName)
        if let events = preset.trackedEvents {
            for event in events {
                event.preset = nil
            }
        }
        // Now delete the preset without cascading to events
        modelContext.delete(preset)
        hapticFeedback()
    }
    
    private func deletePresetKeepEvents(id: UUID) {
        let descriptor = FetchDescriptor<EventPreset>(predicate: #Predicate { $0.id == id })
        if let preset = try? modelContext.fetch(descriptor).first {
            deletePresetKeepEvents(preset)
        }
    }
    
    private func reorderCategories(from source: IndexSet, to destination: Int) {
        var reorderedCategories = editableCategories
        
        // Move items
        reorderedCategories.move(fromOffsets: source, toOffset: destination)
        
        // Update order values
        for (index, category) in reorderedCategories.enumerated() {
            category.order = index
        }

        let nextOrder = reorderedCategories.count
        for category in categories where category.isHiddenCategory {
            category.order = nextOrder
        }
        
        hapticFeedback()
    }
    
    private func hapticFeedback() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }
    
    private func importFromCSV(url: URL) {
        hapticFeedback()
        
        withAnimation(.easeInOut(duration: 0.2)) {
            isImporting = true
        }
        
        Task.detached(priority: .userInitiated) {
            do {
                // Read CSV content (file is already accessible from temp location)
                let csvString = try String(contentsOf: url, encoding: .utf8)
                
                // Clean up temp file after reading
                defer {
                    if url.path.contains("import_") && url.path.contains(".csv") {
                        try? FileManager.default.removeItem(at: url)
                    }
                }
                
                // Parse CSV
                let rows = ManageView.parseCSV(csvString: csvString)
                
                guard !rows.isEmpty else {
                    await MainActor.run {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            self.isImporting = false
                        }
                        self.importResult = ImportResult(success: false, message: "CSV file is empty or invalid. Please check the file format.", importedCount: 0)
                    }
                    return
                }
                
                // Import events on main thread with model context
                await MainActor.run {
                    let result = self.importEvents(from: rows)
                    
                    withAnimation(.easeInOut(duration: 0.2)) {
                        self.isImporting = false
                    }
                    
                    if result.imported > 0 {
                        var messageParts: [String] = []
                        messageParts.append("\(result.imported) event\(result.imported == 1 ? "" : "s")")
                        
                        if result.categoriesCreated > 0 {
                            messageParts.append("\(result.categoriesCreated) categor\(result.categoriesCreated == 1 ? "y" : "ies")")
                        }
                        
                        if result.presetsCreated > 0 {
                            messageParts.append("\(result.presetsCreated) preset\(result.presetsCreated == 1 ? "" : "s")")
                        }
                        
                        var message = "Successfully imported " + messageParts.joined(separator: ", ") + "."
                        
                        if result.skipped > 0 {
                            message += " Skipped \(result.skipped) duplicate\(result.skipped == 1 ? "" : "s")."
                        }
                        
                        self.importResult = ImportResult(
                            success: true,
                            message: message,
                            importedCount: result.imported
                        )
                    } else if result.skipped > 0 {
                        self.importResult = ImportResult(
                            success: false,
                            message: "All \(result.skipped) event\(result.skipped == 1 ? "" : "s") were already imported.",
                            importedCount: 0
                        )
                    } else {
                        self.importResult = ImportResult(
                            success: false,
                            message: "No events were imported. Please check the CSV format matches the export format.",
                            importedCount: 0
                        )
                    }
                }
            } catch {
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        self.isImporting = false
                    }
                    let errorMessage = "Failed to import CSV file: \(error.localizedDescription). Please ensure the file is a valid CSV exported from Tap Tap Track."
                    self.importResult = ImportResult(
                        success: false,
                        message: errorMessage,
                        importedCount: 0
                    )
                }
            }
        }
    }
    
    private func importFromFoursquare(url: URL) {
        hapticFeedback()
        
        withAnimation(.easeInOut(duration: 0.2)) {
            isImporting = true
        }
        
        Task.detached(priority: .userInitiated) {
            do {
                // Start accessing security-scoped resource
                guard url.startAccessingSecurityScopedResource() else {
                    await MainActor.run {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            self.isImporting = false
                        }
                        self.importResult = ImportResult(success: false, message: "Unable to access the selected file.", importedCount: 0)
                    }
                    return
                }
                
                defer {
                    url.stopAccessingSecurityScopedResource()
                }
                
                // Read JSON content
                let jsonData = try Data(contentsOf: url)
                let json = try JSONSerialization.jsonObject(with: jsonData, options: [])
                
                guard let jsonDict = json as? [String: Any],
                      let items = jsonDict["items"] as? [[String: Any]] else {
                    await MainActor.run {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            self.isImporting = false
                        }
                        self.importResult = ImportResult(success: false, message: "Invalid Foursquare JSON format.", importedCount: 0)
                    }
                    return
                }
                
                guard !items.isEmpty else {
                    await MainActor.run {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            self.isImporting = false
                        }
                        self.importResult = ImportResult(success: false, message: "No checkins found in the file.", importedCount: 0)
                    }
                    return
                }
                
                // Import events on main thread with model context
                await MainActor.run {
                    let result = self.importFoursquareCheckins(from: items)
                    
                    withAnimation(.easeInOut(duration: 0.2)) {
                        self.isImporting = false
                    }
                    
                    if result.imported > 0 {
                        var message = "Successfully imported \(result.imported) checkin\(result.imported == 1 ? "" : "s")."
                        if result.skipped > 0 {
                            message += " Skipped \(result.skipped) duplicate\(result.skipped == 1 ? "" : "s")."
                        }
                        self.importResult = ImportResult(
                            success: true,
                            message: message,
                            importedCount: result.imported
                        )
                    } else if result.skipped > 0 {
                        self.importResult = ImportResult(
                            success: false,
                            message: "All \(result.skipped) checkin\(result.skipped == 1 ? "" : "s") were already imported.",
                            importedCount: 0
                        )
                    } else {
                        self.importResult = ImportResult(
                            success: false,
                            message: "No checkins were imported. Please check the file format.",
                            importedCount: 0
                        )
                    }
                }
            } catch {
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        self.isImporting = false
                    }
                    self.importResult = ImportResult(
                        success: false,
                        message: "Failed to read JSON file: \(error.localizedDescription)",
                        importedCount: 0
                    )
                }
            }
        }
    }
    
    private func importEvents(from rows: [CSVRow]) -> (imported: Int, skipped: Int, categoriesCreated: Int, presetsCreated: Int) {
        var importedCount = 0
        var skippedCount = 0
        var categoriesCreated = 0
        var presetsCreated = 0
        
        // Get all existing categories and presets
        let categoryDescriptor = FetchDescriptor<Category>(sortBy: [SortDescriptor(\.name)])
        let presetDescriptor = FetchDescriptor<EventPreset>(sortBy: [SortDescriptor(\.name)])
        let eventDescriptor = FetchDescriptor<TrackedEvent>()
        
        let existingCategories = (try? modelContext.fetch(categoryDescriptor)) ?? []
        let existingPresets = (try? modelContext.fetch(presetDescriptor)) ?? []
        let existingEvents = (try? modelContext.fetch(eventDescriptor)) ?? []
        
        // Create a set of existing events for de-duplication
        // Use timestamp (rounded to nearest minute) + event name as the key
        var existingEventKeys: Set<String> = []
        let calendar = Calendar.current
        for event in existingEvents {
            // Round timestamp to nearest minute for comparison
            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: event.timestamp)
            if let roundedDate = calendar.date(from: components) {
                let timestampKey = String(roundedDate.timeIntervalSince1970)
                let eventKey = "\(timestampKey):\(event.eventName.lowercased())"
                existingEventKeys.insert(eventKey)
            }
        }
        
        // Create a cache for quick lookups
        var categoryCache: [String: Category] = [:]
        for category in existingCategories {
            categoryCache[category.name.lowercased()] = category
        }
        
        var presetCache: [String: EventPreset] = [:]
        for preset in existingPresets {
            let key = "\(preset.name.lowercased()):\(preset.category?.name.lowercased() ?? "none")"
            presetCache[key] = preset
        }
        
        // Date formatters - match the export format
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.locale = Locale.current
        
        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short
        timeFormatter.locale = Locale.current
        
        for row in rows {
            // Parse date and time separately, then combine
            guard let date = dateFormatter.date(from: row.date) else {
                continue
            }
            
            // Parse time - handle both 12-hour and 24-hour formats
            let calendar = Calendar.current
            
            var hour = 0
            var minute = 0
            
            // Try parsing with time formatter first
            if let timeDate = timeFormatter.date(from: row.time) {
                let timeComponents = calendar.dateComponents([.hour, .minute], from: timeDate)
                hour = timeComponents.hour ?? 0
                minute = timeComponents.minute ?? 0
            } else {
                // Fallback: manual parsing
                let timeParts = row.time.components(separatedBy: ":")
                if timeParts.count >= 2 {
                    hour = Int(timeParts[0].trimmingCharacters(in: .whitespaces)) ?? 0
                    let minutePart = timeParts[1].components(separatedBy: " ").first ?? "0"
                    minute = Int(minutePart.trimmingCharacters(in: .whitespaces)) ?? 0
                    
                    // Handle AM/PM
                    let timeUpper = row.time.uppercased()
                    if timeUpper.contains("PM") && hour != 12 {
                        hour += 12
                    } else if timeUpper.contains("AM") && hour == 12 {
                        hour = 0
                    }
                }
            }
            
            guard let combinedDate = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: date) else {
                continue
            }
            
            // Check for duplicate event (same timestamp and event name)
            let eventName = row.event.isEmpty ? "Imported Event" : row.event
            let dateComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: combinedDate)
            if let roundedDate = calendar.date(from: dateComponents) {
                let timestampKey = String(roundedDate.timeIntervalSince1970)
                let eventKey = "\(timestampKey):\(eventName.lowercased())"
                
                if existingEventKeys.contains(eventKey) {
                    skippedCount += 1
                    continue
                }
                
                // Add to existing keys to prevent duplicates within the same import
                existingEventKeys.insert(eventKey)
            }
            
            // Find or create category
            let categoryName = row.category.isEmpty ? "Uncategorized" : row.category
            let categoryKey = categoryName.lowercased()
            let category: Category
            
            if let existing = categoryCache[categoryKey] {
                category = existing
            } else {
                // Create new category
                let maxOrder = existingCategories.map { $0.order }.max() ?? -1
                category = Category(name: categoryName, colorHex: "#6366F1", locationTrackingEnabled: false, order: maxOrder + 1)
                modelContext.insert(category)
                categoryCache[categoryKey] = category
                categoriesCreated += 1
            }
            
            // Detect if this looks like Foursquare data (Imported category with location data)
            let hasLocation = !row.latitude.isEmpty && !row.longitude.isEmpty
            let isImportedCategory = categoryName.lowercased() == "imported"
            let isFoursquareStyle = isImportedCategory && hasLocation && !row.locationName.isEmpty
            
            // Find or create preset
            let preset: EventPreset
            
            if isFoursquareStyle {
                // For Foursquare-style imports, reuse the "Foursquare Checkin" preset
                let foursquarePresetKey = "foursquare checkin:imported"
                if let existing = presetCache[foursquarePresetKey] {
                    preset = existing
                } else {
                    // Check if "Foursquare Checkin" preset already exists
                    if let existingFoursquarePreset = existingPresets.first(where: { 
                        $0.name == "Foursquare Checkin" && $0.category?.name == "Imported" 
                    }) {
                        preset = existingFoursquarePreset
                        presetCache[foursquarePresetKey] = existingFoursquarePreset
                    } else {
                        // Create the Foursquare preset if it doesn't exist
                        preset = EventPreset(
                            name: "Foursquare Checkin",
                            iconName: "location.fill",
                            colorHex: "#8B5CF6",
                            category: category,
                            locationTrackingEnabled: true
                        )
                        modelContext.insert(preset)
                        presetCache[foursquarePresetKey] = preset
                        presetsCreated += 1
                    }
                }
            } else {
                // For regular CSV imports, create presets as before
                let presetKey = "\(eventName.lowercased()):\(categoryKey)"
                
                if let existing = presetCache[presetKey] {
                    preset = existing
                } else {
                    // Create new preset
                    let iconName = row.icon.isEmpty ? "star.fill" : row.icon
                    let colorHex = row.color.isEmpty ? "#667eea" : row.color
                    preset = EventPreset(name: eventName, iconName: iconName, colorHex: colorHex, category: category)
                    modelContext.insert(preset)
                    presetCache[presetKey] = preset
                    presetsCreated += 1
                }
            }
            
            // Restore commas in notes and address (export replaces them with semicolons)
            let notes = row.notes.isEmpty ? nil : row.notes.replacingOccurrences(of: ";", with: ",")
            let address = row.address.isEmpty ? nil : row.address.replacingOccurrences(of: ";", with: ",")
            
            // Create TrackedEvent
            let event = TrackedEvent(
                preset: preset,
                notes: notes,
                latitude: row.latitude.isEmpty ? nil : Double(row.latitude),
                longitude: row.longitude.isEmpty ? nil : Double(row.longitude),
                locationName: row.locationName.isEmpty ? nil : row.locationName,
                address: address,
                numberValue: row.numberValue.isEmpty ? nil : Double(row.numberValue)
            )
            
            // Update timestamp from CSV
            event.timestamp = combinedDate
            
            // Update denormalized data to match CSV (in case preset doesn't match exactly)
            event.eventName = eventName
            event.categoryName = categoryName
            event.iconName = row.icon.isEmpty ? "star.fill" : row.icon
            event.colorHex = row.color.isEmpty ? nil : row.color
            
            modelContext.insert(event)
            importedCount += 1
        }
        
        // Save context
        try? modelContext.save()
        
        return (imported: importedCount, skipped: skippedCount, categoriesCreated: categoriesCreated, presetsCreated: presetsCreated)
    }
    
    private func importFoursquareCheckins(from items: [[String: Any]]) -> (imported: Int, skipped: Int) {
        var importedCount = 0
        var skippedCount = 0
        
        // Get or create "Imported" category
        let categoryDescriptor = FetchDescriptor<Category>(sortBy: [SortDescriptor(\.name)])
        let existingCategories = (try? modelContext.fetch(categoryDescriptor)) ?? []
        
        let importedCategory: Category
        if let existing = existingCategories.first(where: { $0.name.lowercased() == "imported" }) {
            importedCategory = existing
        } else {
            let maxOrder = existingCategories.map { $0.order }.max() ?? -1
            // Location logging is now at preset level, not category level
            importedCategory = Category(name: "Imported", colorHex: "#8B5CF6", locationTrackingEnabled: false, order: maxOrder + 1)
            modelContext.insert(importedCategory)
        }
        
        // Get all existing events for de-duplication
        let eventDescriptor = FetchDescriptor<TrackedEvent>()
        let existingEvents = (try? modelContext.fetch(eventDescriptor)) ?? []
        
        // Create a set of existing events for de-duplication
        var existingEventKeys: Set<String> = []
        let calendar = Calendar.current
        for event in existingEvents {
            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: event.timestamp)
            if let roundedDate = calendar.date(from: components) {
                let timestampKey = String(roundedDate.timeIntervalSince1970)
                let eventKey = "\(timestampKey):\(event.eventName.lowercased())"
                existingEventKeys.insert(eventKey)
            }
        }
        
        // Helper function to parse date with timezone offset
        // The createdAt field represents the local time when the check-in occurred
        // The timeZoneOffset tells us what timezone that local time is in (in minutes from UTC)
        // We parse the string as local time in that timezone, which creates a Date object
        // (stored as UTC internally). When displayed, Swift automatically converts it to
        // the device's current timezone, so the time shown will match the original local time.
        func parseDate(from string: String, timeZoneOffset: Int?) -> Date? {
            // Create date formatters (try multiple formats)
            let dateFormats = ["yyyy-MM-dd HH:mm:ss.SSSSSS", "yyyy-MM-dd HH:mm:ss"]
            
            // Determine the timezone to use for parsing
            let parseTimeZone: TimeZone
            if let offsetMinutes = timeZoneOffset {
                // timeZoneOffset is in minutes from UTC (e.g., -300 = UTC-5 = EST)
                // Create a fixed offset timezone from GMT
                let offsetSeconds = offsetMinutes * 60
                // TimeZone(secondsFromGMT:) returns an optional, so unwrap with fallback
                parseTimeZone = TimeZone(secondsFromGMT: offsetSeconds) ?? TimeZone.current
            } else {
                // If no offset provided, assume the date is already in device's local timezone
                parseTimeZone = TimeZone.current
            }
            
            // Try parsing with each format
            for dateFormat in dateFormats {
                let formatter = DateFormatter()
                formatter.dateFormat = dateFormat
                formatter.locale = Locale(identifier: "en_US_POSIX")
                // CRITICAL: Set the timezone so DateFormatter interprets the string
                // as being in that timezone. This ensures correct conversion to UTC.
                formatter.timeZone = parseTimeZone
                
                // Parse the date string
                // DateFormatter will interpret the string as local time in parseTimeZone,
                // then create a Date object (which is UTC internally)
                // When this Date is later displayed using DateFormatter (without explicit timezone),
                // it will be converted to the device's current timezone, preserving the
                // original local time that was stored.
                if let date = formatter.date(from: string) {
                    return date
                }
            }
            return nil
        }
        
        // Create a default preset for imported checkins (will be reused)
        let presetDescriptor = FetchDescriptor<EventPreset>(sortBy: [SortDescriptor(\.name)])
        let existingPresets = (try? modelContext.fetch(presetDescriptor)) ?? []
        
        let defaultPresetName = "Foursquare Checkin"
        
        let preset: EventPreset
        if let existing = existingPresets.first(where: { $0.name == defaultPresetName && $0.category?.name == "Imported" }) {
            preset = existing
        } else {
            // Foursquare checkins should have location logging enabled
            preset = EventPreset(name: defaultPresetName, iconName: "location.fill", colorHex: "#8B5CF6", category: importedCategory, locationTrackingEnabled: true)
            modelContext.insert(preset)
        }
        
        for item in items {
            // Parse timestamp with timezone information
            guard let createdAtString = item["createdAt"] as? String else {
                continue
            }
            
            // Get timezone offset (in minutes, e.g., -300 = -5 hours = EST)
            let timeZoneOffset = item["timeZoneOffset"] as? Int
            
            // Parse the date using the timezone offset from the checkin
            // This ensures the timestamp is correctly interpreted in the timezone
            // where the checkin occurred, then converted to UTC for storage
            guard let createdAt = parseDate(from: createdAtString, timeZoneOffset: timeZoneOffset) else {
                continue
            }
            
            // Get venue information
            let venue = item["venue"] as? [String: Any]
            let venueName = venue?["name"] as? String ?? "Unknown Location"
            
            // Get location data
            let latitude = item["lat"] as? Double
            let longitude = item["lng"] as? Double
            
            // Check for duplicate event (same timestamp and event name)
            let dateComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: createdAt)
            if let roundedDate = calendar.date(from: dateComponents) {
                let timestampKey = String(roundedDate.timeIntervalSince1970)
                let eventKey = "\(timestampKey):\(venueName.lowercased())"
                
                if existingEventKeys.contains(eventKey) {
                    skippedCount += 1
                    continue
                }
                
                // Add to existing keys to prevent duplicates within the same import
                existingEventKeys.insert(eventKey)
            }
            
            // Create TrackedEvent
            let event = TrackedEvent(
                preset: preset,
                notes: nil,
                latitude: latitude,
                longitude: longitude,
                locationName: venueName,
                address: nil
            )
            
            // Update timestamp from Foursquare data
            event.timestamp = createdAt
            
            // Update denormalized data
            event.eventName = venueName
            event.categoryName = "Imported"
            event.iconName = "location.fill"
            event.colorHex = "#8B5CF6"
            
            modelContext.insert(event)
            importedCount += 1
        }
        
        // Save context
        try? modelContext.save()
        
        return (imported: importedCount, skipped: skippedCount)
    }
    
    nonisolated private static func parseCSV(csvString: String) -> [CSVRow] {
        var rows: [CSVRow] = []
        let lines = csvString.components(separatedBy: .newlines)
        
        guard lines.count > 1 else {
            return rows
        }
        
        // Skip header row
        for i in 1..<lines.count {
            let line = lines[i].trimmingCharacters(in: .whitespacesAndNewlines)
            if line.isEmpty {
                continue
            }
            
            // Simple CSV parsing (handles quoted fields)
            let fields = parseCSVLine(line)
            
            // Support both old format (11 fields) and new format (12 fields with numberValue)
            guard fields.count >= 6 else {
                continue
            }
            
            let row = CSVRow(
                date: fields.count > 0 ? fields[0] : "",
                time: fields.count > 1 ? fields[1] : "",
                event: fields.count > 2 ? fields[2] : "",
                category: fields.count > 3 ? fields[3] : "",
                icon: fields.count > 4 ? fields[4] : "",
                color: fields.count > 5 ? fields[5] : "",
                notes: fields.count > 6 ? fields[6] : "",
                latitude: fields.count > 7 ? fields[7] : "",
                longitude: fields.count > 8 ? fields[8] : "",
                locationName: fields.count > 9 ? fields[9] : "",
                address: fields.count > 10 ? fields[10] : "",
                numberValue: fields.count > 11 ? fields[11] : ""
            )
            
            rows.append(row)
        }
        
        return rows
    }
    
    nonisolated private static func parseCSVLine(_ line: String) -> [String] {
        var fields: [String] = []
        var currentField = ""
        var insideQuotes = false
        
        for char in line {
            if char == "\"" {
                insideQuotes.toggle()
            } else if char == "," && !insideQuotes {
                fields.append(currentField.trimmingCharacters(in: .whitespaces))
                currentField = ""
            } else {
                currentField.append(char)
            }
        }
        
        // Add the last field
        fields.append(currentField.trimmingCharacters(in: .whitespaces))
        
        return fields
    }
}

// MARK: - Categories Section
struct CategoriesSection: View {
    let categories: [Category]
    let onAdd: () -> Void
    let onEdit: (Category) -> Void
    let onDelete: (Category) -> Void
    let onMove: (IndexSet, Int) -> Void
    
    @State private var editMode: EditMode = .inactive
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Categories")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
                
                Spacer()
                
                HStack(spacing: 12) {
                    // Edit/Done button for reordering
                    Button(action: {
                        withAnimation {
                            editMode = editMode == .active ? .inactive : .active
                        }
                    }) {
                        Text(editMode == .active ? "Done" : "Move")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .fixedSize(horizontal: true, vertical: false)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(editMode == .active ? Color(hex: "#667eea")! : Color(hex: "#2a2a4e")!)
                            )
                    }
                    
                    Button(action: onAdd) {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                            Text("Add")
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            LinearGradient(
                                colors: [Color(hex: "#667eea")!, Color(hex: "#764ba2")!],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(20)
                    }
                }
            }
            .padding(.horizontal, 20)
            
            if categories.isEmpty {
                Text("No categories yet. Tap Add to create one.")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 20)
            } else {
                List {
                    ForEach(categories) { category in
                        CategoryCard(
                            category: category,
                            onEdit: { onEdit(category) },
                            onDelete: { onDelete(category) },
                            showDragHandle: editMode == .active
                        )
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
                        .listRowSeparator(.hidden)
                    }
                    .onMove(perform: onMove)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .environment(\.editMode, $editMode)
                .frame(height: max(0, CGFloat(categories.count) * 72 + 20))
            }
        }
    }
}

struct CategoryCard: View {
    let category: Category
    let onEdit: () -> Void
    let onDelete: () -> Void
    let showDragHandle: Bool
    
    var body: some View {
        HStack {
            // Category name
            Text(category.name)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
            
            Spacer()
            
            // Edit button (hidden in edit mode)
            if !showDragHandle {
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .font(.system(size: 16))
                        .foregroundColor(Color(hex: "#60A5FA")!)
                }
                .frame(width: 36, height: 36)
                .contentShape(Rectangle())
                .buttonStyle(.plain)
                .padding(.trailing, 8)
            }
            
            // Delete button (hidden in edit mode)
            if !showDragHandle {
                Button(action: onDelete) {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 16))
                        .foregroundColor(Color(hex: "#EF4444")!)
                }
                .frame(width: 36, height: 36)
                .contentShape(Rectangle())
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(hex: "#252540")!)
        )
    }
}

// MARK: - Presets Section
struct PresetsSection: View {
    let presets: [EventPreset]
    let onAdd: () -> Void
    let onEdit: (EventPreset) -> Void
    let onDelete: (EventPreset) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Event Presets")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
                
                Spacer()
                
                Button(action: onAdd) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                        Text("Add")
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: "#667eea")!, Color(hex: "#764ba2")!],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(20)
                }
            }
            .padding(.horizontal, 20)
            
            VStack(spacing: 12) {
                ForEach(presets) { preset in
                    PresetCard(
                        preset: preset,
                        onEdit: { onEdit(preset) },
                        onDelete: { onDelete(preset) }
                    )
                }
            }
            .padding(.horizontal, 20)
        }
    }
}

struct PresetCard: View {
    let preset: EventPreset
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(preset.color.opacity(0.2))
                    .frame(width: 44, height: 44)
                
                Image(systemName: preset.iconName)
                    .font(.system(size: 18))
                    .foregroundColor(preset.color)
            }
            
            // Info
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(preset.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    
                    // Location indicator
                    if preset.locationTrackingEnabled {
                        Image(systemName: "location.fill")
                            .font(.system(size: 11))
                            .foregroundColor(Color(hex: "#60A5FA")!)
                    }
                    
                    // Number indicator
                    if preset.numberEnabled {
                        Image(systemName: "number")
                            .font(.system(size: 11))
                            .foregroundColor(Color(hex: "#60A5FA")!)
                    }
                }
                
                Text(preset.category?.name ?? "No Category")
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            // Edit button
            Button(action: onEdit) {
                Image(systemName: "pencil")
                    .font(.system(size: 16))
                    .foregroundColor(Color(hex: "#60A5FA")!)
            }
            .padding(.trailing, 8)
            
            // Delete button
            Button(action: onDelete) {
                Image(systemName: "trash.fill")
                    .font(.system(size: 16))
                    .foregroundColor(Color(hex: "#EF4444")!)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(hex: "#252540")!)
        )
    }
}

// MARK: - Floating Action Button
struct FloatingActionButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color(hex: "#e5e5e5")!)
                    .frame(width: 56, height: 56)
                    .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                
                Image(systemName: "pencil")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(.black)
            }
        }
    }
}

// MARK: - Add Category Sheet
struct AddCategorySheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var categoryName = ""
    let onSave: (String) -> Void
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "#1a1a2e")!.ignoresSafeArea()
                
                VStack(spacing: 24) {
                    Text("New Category")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                    
                    TextField("Category name", text: $categoryName)
                        .textFieldStyle(DarkTextFieldStyle())
                        .padding(.horizontal)
                    
                    HStack(spacing: 16) {
                        Button("Cancel") {
                            dismiss()
                        }
                        .buttonStyle(SecondaryButtonStyle())
                        
                        Button("Create") {
                            if !categoryName.isEmpty {
                                onSave(categoryName)
                                dismiss()
                            }
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(categoryName.isEmpty)
                    }
                    .padding(.horizontal)
                    
                    Spacer()
                }
                .padding(.top, 32)
            }
            .navigationBarHidden(true)
        }
    }
}

// MARK: - Edit Category Sheet
struct EditCategorySheet: View {
    @Environment(\.dismiss) private var dismiss
    let category: Category
    let onSave: (String) -> Void
    
    @State private var categoryName: String
    
    init(category: Category, onSave: @escaping (String) -> Void) {
        self.category = category
        self.onSave = onSave
        _categoryName = State(initialValue: category.name)
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "#1a1a2e")!.ignoresSafeArea()
                
                VStack(spacing: 24) {
                    Text("Edit Category")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                    
                    TextField("Category name", text: $categoryName)
                        .textFieldStyle(DarkTextFieldStyle())
                        .padding(.horizontal)
                    
                    HStack(spacing: 16) {
                        Button("Cancel") {
                            dismiss()
                        }
                        .buttonStyle(SecondaryButtonStyle())
                        
                        Button("Save") {
                            if !categoryName.isEmpty {
                                onSave(categoryName)
                                dismiss()
                            }
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(categoryName.isEmpty)
                    }
                    .padding(.horizontal)
                    
                    Spacer()
                }
                .padding(.top, 32)
            }
            .navigationBarHidden(true)
        }
    }
}

// MARK: - Add Preset Sheet
struct AddPresetSheet: View {
    @Environment(\.dismiss) private var dismiss
    let categories: [Category]
    let onSave: (String, String, String, Category?, Bool, Double?, Double?, Bool, Bool, Bool) -> Void
    
    @State private var presetName = ""
    @State private var selectedIcon = "star.fill"
    @State private var selectedColorHex = "#667eea"
    @State private var selectedCategory: Category?
    @State private var numberEnabled = false
    @State private var numberMin: Double? = nil
    @State private var numberMax: Double? = nil
    @State private var numberAllowDecimals = false
    @State private var numberRequired = false
    @State private var locationTrackingEnabled = false
    @StateObject private var locationManager = LocationManager()
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "#1a1a2e")!.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        Text("New Event Preset")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                        
                        // Name field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Name")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.gray)
                            
                            TextField("Preset name", text: $presetName)
                                .textFieldStyle(DarkTextFieldStyle())
                        }
                        .padding(.horizontal)
                        
                        // Icon picker
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Icon")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.gray)
                                .padding(.horizontal)
                            
                            IconPicker(selectedIcon: $selectedIcon)
                        }
                        
                        // Color picker
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Color")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.gray)
                                .padding(.horizontal)
                            
                            ColorPicker(selectedColorHex: $selectedColorHex)
                        }
                        
                        // Category picker
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Category")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.gray)
                            
                            CategoryPicker(categories: categories, selectedCategory: $selectedCategory)
                        }
                        .padding(.horizontal)
                        
                        // Number input configuration
                        NumberInputConfigSection(
                            numberEnabled: $numberEnabled,
                            numberMin: $numberMin,
                            numberMax: $numberMax,
                            numberAllowDecimals: $numberAllowDecimals,
                            numberRequired: $numberRequired
                        )
                        
                        // Location logging configuration
                        LocationTrackingConfigSection(
                            locationTrackingEnabled: $locationTrackingEnabled,
                            locationManager: locationManager
                        )
                        
                        HStack(spacing: 16) {
                            Button("Cancel") {
                                dismiss()
                            }
                            .buttonStyle(SecondaryButtonStyle())
                            
                            Button("Create") {
                                if !presetName.isEmpty {
                                    onSave(presetName, selectedIcon, selectedColorHex, selectedCategory, numberEnabled, numberMin, numberMax, numberAllowDecimals, numberRequired, locationTrackingEnabled)
                                    dismiss()
                                }
                            }
                            .buttonStyle(PrimaryButtonStyle())
                            .disabled(presetName.isEmpty)
                        }
                        .padding(.horizontal)
                        .padding(.top, 16)
                    }
                    .padding(.top, 32)
                    .padding(.bottom, 40)
                }
            }
            .navigationBarHidden(true)
        }
    }
}

// MARK: - Edit Preset Sheet
struct EditPresetSheet: View {
    @Environment(\.dismiss) private var dismiss
    let preset: EventPreset
    let categories: [Category]
    let onSave: (String, String, String, Category?, Bool, Double?, Double?, Bool, Bool, Bool) -> Void
    
    @State private var presetName: String
    @State private var selectedIcon: String
    @State private var selectedColorHex: String
    @State private var selectedCategory: Category?
    @State private var numberEnabled: Bool
    @State private var numberMin: Double?
    @State private var numberMax: Double?
    @State private var numberAllowDecimals: Bool
    @State private var numberRequired: Bool
    @State private var locationTrackingEnabled: Bool
    @StateObject private var locationManager = LocationManager()
    
    init(preset: EventPreset, categories: [Category], onSave: @escaping (String, String, String, Category?, Bool, Double?, Double?, Bool, Bool, Bool) -> Void) {
        self.preset = preset
        self.categories = categories
        self.onSave = onSave
        _presetName = State(initialValue: preset.name)
        _selectedIcon = State(initialValue: preset.iconName)
        _selectedColorHex = State(initialValue: preset.colorHex ?? "#667eea")
        _selectedCategory = State(initialValue: preset.category)
        _numberEnabled = State(initialValue: preset.numberEnabled)
        _numberMin = State(initialValue: preset.numberMin)
        _numberMax = State(initialValue: preset.numberMax)
        _numberAllowDecimals = State(initialValue: preset.numberAllowDecimals)
        _numberRequired = State(initialValue: preset.numberRequired)
        _locationTrackingEnabled = State(initialValue: preset.locationTrackingEnabled)
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "#1a1a2e")!.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        Text("Edit Event Preset")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                        
                        // Name field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Name")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.gray)
                            
                            TextField("Preset name", text: $presetName)
                                .textFieldStyle(DarkTextFieldStyle())
                        }
                        .padding(.horizontal)
                        
                        // Category picker
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Category")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.gray)
                            
                            CategoryPicker(categories: categories, selectedCategory: $selectedCategory)
                        }
                        .padding(.horizontal)
                        
                        // Icon picker
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Icon")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.gray)
                                .padding(.horizontal)
                            
                            IconPicker(selectedIcon: $selectedIcon)
                        }
                        
                        // Color picker
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Color")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.gray)
                                .padding(.horizontal)
                            
                            ColorPicker(selectedColorHex: $selectedColorHex)
                        }
                        
                        // Number input configuration
                        NumberInputConfigSection(
                            numberEnabled: $numberEnabled,
                            numberMin: $numberMin,
                            numberMax: $numberMax,
                            numberAllowDecimals: $numberAllowDecimals,
                            numberRequired: $numberRequired
                        )
                        
                        // Location logging configuration
                        LocationTrackingConfigSection(
                            locationTrackingEnabled: $locationTrackingEnabled,
                            locationManager: locationManager
                        )
                        
                        HStack(spacing: 16) {
                            Button("Cancel") {
                                dismiss()
                            }
                            .buttonStyle(SecondaryButtonStyle())
                            
                            Button("Save") {
                                if !presetName.isEmpty {
                                    onSave(presetName, selectedIcon, selectedColorHex, selectedCategory, numberEnabled, numberMin, numberMax, numberAllowDecimals, numberRequired, locationTrackingEnabled)
                                    dismiss()
                                }
                            }
                            .buttonStyle(PrimaryButtonStyle())
                            .disabled(presetName.isEmpty)
                        }
                        .padding(.horizontal)
                        .padding(.top, 16)
                    }
                    .padding(.top, 32)
                    .padding(.bottom, 40)
                }
            }
            .navigationBarHidden(true)
        }
    }
}

// MARK: - Icon Picker
struct IconPicker: View {
    @Binding var selectedIcon: String
    @State private var searchText = ""
    @State private var expandedCategory: String? = nil
    
    private let columns = [
        GridItem(.adaptive(minimum: 44), spacing: 8)
    ]
    
    private var filteredCategories: [(category: String, icons: [(name: String, systemName: String)])] {
        if searchText.isEmpty {
            return EventPreset.iconCategories
        }
        
        let lowercasedSearch = searchText.lowercased()
        return EventPreset.iconCategories.compactMap { category in
            let filteredIcons = category.icons.filter { icon in
                icon.name.lowercased().contains(lowercasedSearch)
            }
            if filteredIcons.isEmpty {
                return nil
            }
            return (category: category.category, icons: filteredIcons)
        }
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                
                TextField("Search icons...", text: $searchText)
                    .foregroundColor(.white)
                
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(12)
            .background(Color(hex: "#252540")!)
            .cornerRadius(12)
            .padding(.horizontal)
            
            // Selected icon preview
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "#667eea")!, Color(hex: "#764ba2")!],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 56, height: 56)
                    
                    Image(systemName: selectedIcon)
                        .font(.system(size: 26))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Selected Icon")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                    
                    Text(iconName(for: selectedIcon))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                }
                
                Spacer()
            }
            .padding(.horizontal)
            
            // Icon categories
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(filteredCategories, id: \.category) { categoryData in
                        IconCategorySection(
                            category: categoryData.category,
                            icons: categoryData.icons,
                            selectedIcon: $selectedIcon,
                            isExpanded: expandedCategory == categoryData.category || !searchText.isEmpty,
                            onToggle: {
                                withAnimation(.spring(response: 0.3)) {
                                    if expandedCategory == categoryData.category {
                                        expandedCategory = nil
                                    } else {
                                        expandedCategory = categoryData.category
                                    }
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            .frame(maxHeight: 300)
        }
    }
    
    private func iconName(for systemName: String) -> String {
        for category in EventPreset.iconCategories {
            if let icon = category.icons.first(where: { $0.systemName == systemName }) {
                return icon.name
            }
        }
        return systemName
    }
}

// MARK: - Icon Category Section
struct IconCategorySection: View {
    let category: String
    let icons: [(name: String, systemName: String)]
    @Binding var selectedIcon: String
    let isExpanded: Bool
    let onToggle: () -> Void
    
    private let columns = [
        GridItem(.adaptive(minimum: 44), spacing: 8)
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Category header
            Button(action: onToggle) {
                HStack {
                    Text(category)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text("(\(icons.count))")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.gray)
                }
                .padding(.vertical, 8)
            }
            
            // Icons grid
            if isExpanded {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(icons, id: \.systemName) { icon in
                        Button {
                            selectedIcon = icon.systemName
                            
                            // Haptic feedback
                            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                            impactFeedback.impactOccurred()
                        } label: {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(selectedIcon == icon.systemName 
                                          ? Color(hex: "#667eea")! 
                                          : Color(hex: "#2a2a4e")!)
                                    .frame(width: 44, height: 44)
                                
                                Image(systemName: icon.systemName)
                                    .font(.system(size: 18))
                                    .foregroundColor(.white)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            } else {
                // Show preview of first few icons when collapsed
                HStack(spacing: 6) {
                    ForEach(icons.prefix(6), id: \.systemName) { icon in
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(selectedIcon == icon.systemName 
                                      ? Color(hex: "#667eea")! 
                                      : Color(hex: "#2a2a4e")!)
                                .frame(width: 36, height: 36)
                            
                            Image(systemName: icon.systemName)
                                .font(.system(size: 14))
                                .foregroundColor(.white)
                        }
                        .onTapGesture {
                            selectedIcon = icon.systemName
                            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                            impactFeedback.impactOccurred()
                        }
                    }
                    
                    if icons.count > 6 {
                        Text("+\(icons.count - 6)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.gray)
                            .padding(.horizontal, 8)
                    }
                    
                    Spacer()
                }
            }
        }
        .padding(12)
        .background(Color(hex: "#252540")!)
        .cornerRadius(12)
    }
}

// MARK: - Category Picker
struct CategoryPicker: View {
    let categories: [Category]
    @Binding var selectedCategory: Category?
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                Button {
                    selectedCategory = nil
                } label: {
                    Text("Uncategorized")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(selectedCategory == nil
                                      ? Color(hex: "#667eea")!
                                      : Color(hex: "#2a2a4e")!)
                        )
                }

                ForEach(categories) { category in
                    Button {
                        selectedCategory = category
                    } label: {
                        Text(category.name)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(selectedCategory?.id == category.id 
                                          ? Color(hex: "#667eea")! 
                                          : Color(hex: "#2a2a4e")!)
                            )
                    }
                }
            }
        }
    }
}

// MARK: - Dark Text Field Style
struct DarkTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding()
            .background(Color(hex: "#2a2a4e")!)
            .foregroundColor(.white)
            .cornerRadius(12)
    }
}

// MARK: - About Section
struct AboutSection: View {
    let onTap: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("About")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 20)
            
            Button(action: onTap) {
                HStack(spacing: 16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "#667eea")!, Color(hex: "#764ba2")!],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 44, height: 44)
                        
                        Image(systemName: "hand.tap.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Tap Tap Track")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                        
                        Text("How to use & app info")
                            .font(.system(size: 13))
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.gray)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(hex: "#252540")!)
                )
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.horizontal, 20)
        }
    }
}

// MARK: - About Sheet
struct AboutSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "#1a1a2e")!.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 32) {
                        // App Logo & Name
                        VStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color(hex: "#667eea")!, Color(hex: "#764ba2")!],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 100, height: 100)
                                
                                Image(systemName: "hand.tap.fill")
                                    .font(.system(size: 44))
                                    .foregroundColor(.white)
                            }
                            
                            Text("Tap Tap Track")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text("Simple Event Tracking")
                                .font(.system(size: 16))
                                .foregroundColor(.gray)
                        }
                        .padding(.top, 24)
                        
                        // How to Use Section
                        VStack(alignment: .leading, spacing: 20) {
                            Text("How to Use")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                            
                            HowToItem(
                                icon: "hand.tap",
                                title: "Quick Track",
                                description: "Tap any event button to instantly log it with the current time."
                            )
                            
                            HowToItem(
                                icon: "hand.tap.fill",
                                title: "Track with Details",
                                description: "Long-press an event button to log it and immediately edit the time, date, or add notes."
                            )
                            
                            HowToItem(
                                icon: "clock.arrow.circlepath",
                                title: "View History",
                                description: "Switch to the History tab to see all your tracked events. Tap the edit icon to modify any entry."
                            )
                            
                            HowToItem(
                                icon: "slider.horizontal.3",
                                title: "Customize",
                                description: "Use the Manage tab to create your own categories and event presets with custom icons and colors."
                            )
                            
                            HowToItem(
                                icon: "location.fill",
                                title: "Location Logging",
                                description: "Enable location logging for categories to automatically capture GPS coordinates and nearby business names when tracking events."
                            )
                            
                            HowToItem(
                                icon: "chart.line.uptrend.xyaxis",
                                title: "View Trends",
                                description: "Switch to the Trends tab to see charts and statistics about your tracked events over time."
                            )
                            
                            HowToItem(
                                icon: "arrow.down.doc.fill",
                                title: "Export Data",
                                description: "Export your event history to CSV from the History tab for backup or analysis."
                            )
                        }
                        .padding(20)
                        .background(Color(hex: "#252540")!)
                        .cornerRadius(20)
                        .padding(.horizontal, 20)
                        
                        // Tips Section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Tips")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                            
                            TipItem(text: "Events auto-save when you tap, so tracking is instant")
                            TipItem(text: "The confirmation popup auto-dismisses after 5 seconds")
                            TipItem(text: "Use categories to organize similar events together")
                            TipItem(text: "Pick custom colors for each preset to make them easy to identify")
                            TipItem(text: "Add notes to remember context about specific events")
                            TipItem(text: "Check the Trends tab to see patterns in your tracking over time")
                        }
                        .padding(20)
                        .background(Color(hex: "#252540")!)
                        .cornerRadius(20)
                        .padding(.horizontal, 20)
                        
                        // Version
                        Text("Version 1.4.1")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                            .padding(.top, 8)
                        
                        Spacer(minLength: 40)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(Color(hex: "#60A5FA")!)
                }
            }
        }
    }
}

// MARK: - How To Item
struct HowToItem: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color(hex: "#3a3a5e")!)
                    .frame(width: 40, height: 40)
                
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(Color(hex: "#60A5FA")!)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                
                Text(description)
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Tip Item
struct TipItem: View {
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "lightbulb.fill")
                .font(.system(size: 14))
                .foregroundColor(Color(hex: "#FBBF24")!)
            
            Text(text)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Color Picker
struct ColorPicker: View {
    @Binding var selectedColorHex: String
    
    // Curated color palette - vibrant but clean colors
    private let colorOptions: [(name: String, hex: String)] = [
        ("Purple", "#667eea"),
        ("Violet", "#764ba2"),
        ("Blue", "#60A5FA"),
        ("Cyan", "#06B6D4"),
        ("Teal", "#14B8A6"),
        ("Green", "#10B981"),
        ("Lime", "#84CC16"),
        ("Yellow", "#FBBF24"),
        ("Orange", "#F97316"),
        ("Red", "#EF4444"),
        ("Pink", "#EC4899"),
        ("Rose", "#F43F5E"),
        ("Indigo", "#6366F1"),
        ("Sky", "#0EA5E9"),
        ("Emerald", "#059669"),
        ("Amber", "#D97706"),
    ]
    
    private let columns = [
        GridItem(.adaptive(minimum: 50), spacing: 12)
    ]
    
    var body: some View {
        VStack(spacing: 12) {
            // Selected color preview
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(hex: selectedColorHex) ?? Color(hex: "#667eea")!)
                        .frame(width: 56, height: 56)
                    
                    Image(systemName: "checkmark")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                        .opacity(0.9)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Selected Color")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                    
                    Text(colorName(for: selectedColorHex))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                }
                
                Spacer()
            }
            .padding(.horizontal)
            
            // Color grid
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(colorOptions, id: \.hex) { color in
                    Button {
                        selectedColorHex = color.hex
                        
                        // Haptic feedback
                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                        impactFeedback.impactOccurred()
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color(hex: color.hex)!)
                                .frame(width: 44, height: 44)
                            
                            if selectedColorHex == color.hex {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                        .overlay(
                            Circle()
                                .stroke(selectedColorHex == color.hex ? Color.white : Color.clear, lineWidth: 3)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal)
        }
    }
    
    private func colorName(for hex: String) -> String {
        colorOptions.first(where: { $0.hex == hex })?.name ?? "Custom"
    }
}

// MARK: - Import Section
struct ImportSection: View {
    let isImporting: Bool
    let onCSVImport: () -> Void
    let onFoursquareImport: () -> Void
    let onFoursquareHelp: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Import Data")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 20)
            
            // CSV Import Button
            Button(action: onCSVImport) {
                HStack(spacing: 16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "#10b981")!, Color(hex: "#059669")!],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 44, height: 44)
                        
                        ZStack {
                            if isImporting {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(1.2)
                            } else {
                                Image(systemName: "arrow.up.doc.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(.white)
                            }
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Import Tap Tap Track Data")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                        
                        Text("Import events from a CSV file")
                            .font(.system(size: 13))
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    if !isImporting {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.gray)
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(hex: "#252540")!)
                )
                .opacity(isImporting ? 0.6 : 1.0)
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(isImporting)
            .padding(.horizontal, 20)
            
            // Foursquare Import Button with Help
            VStack(spacing: 12) {
                Button(action: onFoursquareImport) {
                    HStack(spacing: 16) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(
                                    LinearGradient(
                                        colors: [Color(hex: "#667eea")!, Color(hex: "#764ba2")!],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 44, height: 44)
                            
                            ZStack {
                                if isImporting {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(1.2)
                                } else {
                                    Image(systemName: "location.fill")
                                        .font(.system(size: 20))
                                        .foregroundColor(.white)
                                }
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Import Foursquare Checkins")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                            
                            Text("Import checkins from Foursquare JSON")
                                .font(.system(size: 13))
                                .foregroundColor(.gray)
                        }
                        
                        Spacer()
                        
                        if !isImporting {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(hex: "#252540")!)
                    )
                    .opacity(isImporting ? 0.6 : 1.0)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(isImporting)
                
                // Help Button
                Button(action: onFoursquareHelp) {
                    HStack(spacing: 8) {
                        Image(systemName: "questionmark.circle.fill")
                            .font(.system(size: 14))
                        Text("How to get your Foursquare data")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundColor(Color(hex: "#60A5FA")!)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(hex: "#252540")!)
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 20)
        }
    }
}

// MARK: - CSV Row
struct CSVRow {
    let date: String
    let time: String
    let event: String
    let category: String
    let icon: String
    let color: String
    let notes: String
    let latitude: String
    let longitude: String
    let locationName: String
    let address: String
    let numberValue: String
}

// MARK: - Import Result
struct ImportResult: Identifiable {
    let id = UUID()
    let success: Bool
    let message: String
    let importedCount: Int
}

// MARK: - Foursquare Import Help Sheet
struct FoursquareImportHelpSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "#1a1a2e")!.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color(hex: "#667eea")!, Color(hex: "#764ba2")!],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 80, height: 80)
                                
                                Image(systemName: "location.fill")
                                    .font(.system(size: 36))
                                    .foregroundColor(.white)
                            }
                            
                            Text("Import Foursquare Checkins")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text("Bring your checkin history into Tap Tap Track")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 24)
                        
                        // Overview Section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Overview")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                            
                            VStack(alignment: .leading, spacing: 12) {
                                HelpStep(
                                    number: "1",
                                    title: "Request Your Data",
                                    description: "Open the Swarm app and request a download of your checkin data through the privacy settings."
                                )
                                
                                HelpStep(
                                    number: "2",
                                    title: "Download the ZIP File",
                                    description: "Once you receive the email from Foursquare, download the ZIP file to your iPhone."
                                )
                                
                                HelpStep(
                                    number: "3",
                                    title: "Extract and Import",
                                    description: "Open the ZIP file, navigate to the checkins JSON file, and import it into Tap Tap Track."
                                )
                            }
                        }
                        .padding(20)
                        .background(Color(hex: "#252540")!)
                        .cornerRadius(20)
                        .padding(.horizontal, 20)
                        
                        // Detailed Guide Button
                        Button {
                            if let url = URL(string: "https://taptaptrack.com/foursquare-import.html") {
                                openURL(url)
                            }
                        } label: {
                            HStack {
                                Image(systemName: "safari.fill")
                                    .font(.system(size: 16))
                                Text("View Step-by-Step Guide")
                                    .font(.system(size: 16, weight: .semibold))
                                Spacer()
                                Image(systemName: "arrow.up.right.square")
                                    .font(.system(size: 14))
                            }
                            .foregroundColor(.white)
                            .padding()
                            .background(
                                LinearGradient(
                                    colors: [Color(hex: "#60A5FA")!, Color(hex: "#3B82F6")!],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(12)
                        }
                        .padding(.horizontal, 20)
                        
                        // Tips Section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Tips")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                            
                            VStack(alignment: .leading, spacing: 12) {
                                TipItem(text: "The import process creates an 'Imported' category for your checkins")
                                TipItem(text: "All location data (venue names, coordinates) will be preserved")
                                TipItem(text: "Original timestamps are maintained, converted to your local timezone")
                                TipItem(text: "You can import multiple JSON files if your data is split across files")
                            }
                        }
                        .padding(20)
                        .background(Color(hex: "#252540")!)
                        .cornerRadius(20)
                        .padding(.horizontal, 20)
                        
                        Spacer(minLength: 40)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(Color(hex: "#60A5FA")!)
                }
            }
        }
    }
}

// MARK: - Help Step
struct HelpStep: View {
    let number: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color(hex: "#667eea")!)
                    .frame(width: 32, height: 32)
                
                Text(number)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                
                Text(description)
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
    }
}

// MARK: - Number Input Config Section
struct NumberInputConfigSection: View {
    @Binding var numberEnabled: Bool
    @Binding var numberMin: Double?
    @Binding var numberMax: Double?
    @Binding var numberAllowDecimals: Bool
    @Binding var numberRequired: Bool
    
    @State private var minText: String = ""
    @State private var maxText: String = ""
    @State private var showMinError = false
    @State private var showMaxError = false
    @State private var showRangeError = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "number")
                    .font(.system(size: 16))
                    .foregroundColor(.gray)
                
                Text("Enable Number Input")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                
                Spacer()
                
                Toggle("", isOn: $numberEnabled)
                    .tint(Color(hex: "#667eea")!)
            }
            
            if numberEnabled {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Configure the number input for this event type. Set min and max values to show a slider, or leave them empty to allow any number. Users can always enter numbers directly.")
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                    
                    // Min value
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Minimum Value (Optional)")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                        
                        TextField("Leave empty for no limit", text: $minText)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(DarkTextFieldStyle())
                            .onChange(of: minText) { oldValue, newValue in
                                if let value = Double(newValue) {
                                    numberMin = value
                                    showMinError = false
                                    validateRange()
                                } else if newValue.isEmpty {
                                    numberMin = nil
                                    showMinError = false
                                    validateRange()
                                } else {
                                    showMinError = true
                                }
                            }
                        
                        if showMinError {
                            Text("Please enter a valid number")
                                .font(.system(size: 11))
                                .foregroundColor(Color(hex: "#EF4444")!)
                        }
                    }
                    
                    // Max value
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Maximum Value (Optional)")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                        
                        TextField("Leave empty for no limit", text: $maxText)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(DarkTextFieldStyle())
                            .onChange(of: maxText) { oldValue, newValue in
                                if let value = Double(newValue) {
                                    numberMax = value
                                    showMaxError = false
                                    validateRange()
                                } else if newValue.isEmpty {
                                    numberMax = nil
                                    showMaxError = false
                                    validateRange()
                                } else {
                                    showMaxError = true
                                }
                            }
                        
                        if showMaxError {
                            Text("Please enter a valid number")
                                .font(.system(size: 11))
                                .foregroundColor(Color(hex: "#EF4444")!)
                        }
                    }
                    
                    if showRangeError {
                        Text("Maximum must be greater than minimum")
                            .font(.system(size: 11))
                            .foregroundColor(Color(hex: "#EF4444")!)
                    }
                    
                    // Allow Decimals toggle
                    HStack {
                        Image(systemName: "number.square")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                        
                        Text("Allow Decimals")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Toggle("", isOn: $numberAllowDecimals)
                            .tint(Color(hex: "#667eea")!)
                    }
                    .padding(.top, 4)
                    
                    // Required toggle
                    HStack {
                        Image(systemName: "exclamationmark.circle")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                        
                        Text("Required")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Toggle("", isOn: $numberRequired)
                            .tint(Color(hex: "#667eea")!)
                    }
                    .padding(.top, 4)
                }
                .padding(.top, 8)
            }
        }
        .padding()
        .background(Color(hex: "#252540")!)
        .cornerRadius(16)
        .padding(.horizontal)
        .onAppear {
            if let min = numberMin {
                minText = numberAllowDecimals ? String(min) : String(format: "%.0f", min)
            }
            if let max = numberMax {
                maxText = numberAllowDecimals ? String(max) : String(format: "%.0f", max)
            }
        }
    }
    
    private func validateRange() {
        if let min = numberMin, let max = numberMax {
            // Only validate if both are set
            showRangeError = max <= min
        } else {
            // If either is missing, no range error
            showRangeError = false
        }
    }
}

// MARK: - Location Logging Config Section
struct LocationTrackingConfigSection: View {
    @Binding var locationTrackingEnabled: Bool
    @ObservedObject var locationManager: LocationManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "location.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.gray)
                
                Text("Enable Location Logging")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                
                Spacer()
                
                Toggle("", isOn: $locationTrackingEnabled)
                    .tint(Color(hex: "#667eea")!)
                    .onChange(of: locationTrackingEnabled) { oldValue, newValue in
                        if newValue && locationManager.authorizationStatus == .notDetermined {
                            locationManager.requestPermission()
                        }
                    }
            }
            
            if locationTrackingEnabled {
                Text("When enabled, events tracked with this preset will automatically capture your location and nearby business names.")
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
                    .padding(.top, 4)
            }
        }
        .padding()
        .background(Color(hex: "#252540")!)
        .cornerRadius(16)
        .padding(.horizontal)
    }
}

// MARK: - Document Picker Presenter (Alternative to fileImporter)
struct DocumentPickerPresenter: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let allowedContentTypes: [UTType]
    let onDocumentPicked: (URL) -> Void
    let onCancel: () -> Void
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPickerPresenter
        var hasPresented = false
        
        init(_ parent: DocumentPickerPresenter) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            // Immediately set isPresented to false to prevent re-presenting
            parent.isPresented = false
            hasPresented = false
            
            if let url = urls.first {
                // Start accessing security-scoped resource before dismissing
                let _ = url.startAccessingSecurityScopedResource()
                
                // Copy file to a location we can access later
                let tempDir = FileManager.default.temporaryDirectory
                let tempURL = tempDir.appendingPathComponent("import_\(UUID().uuidString).csv")
                
                do {
                    // Remove old temp file if exists
                    if FileManager.default.fileExists(atPath: tempURL.path) {
                        try? FileManager.default.removeItem(at: tempURL)
                    }
                    
                    // Copy file to temp location while we have access
                    try FileManager.default.copyItem(at: url, to: tempURL)
                    
                    // Stop accessing security-scoped resource
                    url.stopAccessingSecurityScopedResource()
                    
                    // Dismiss and use the temp file
                    controller.dismiss(animated: true) {
                        self.parent.onDocumentPicked(tempURL)
                    }
                } catch {
                    url.stopAccessingSecurityScopedResource()
                    controller.dismiss(animated: true) {
                        self.parent.onCancel()
                    }
                }
            } else {
                controller.dismiss(animated: true) {
                    self.parent.onCancel()
                }
            }
        }
        
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            // Immediately set isPresented to false to prevent re-presenting
            parent.isPresented = false
            hasPresented = false
            controller.dismiss(animated: true) {
                self.parent.onCancel()
            }
        }
    }
    
    func makeUIViewController(context: Context) -> UIViewController {
        return UIViewController()
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        let coordinator = context.coordinator
        
        // Only present if isPresented is true and we haven't already presented
        if isPresented && !coordinator.hasPresented {
            // Check if picker is already presented before setting flag
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootViewController = windowScene.windows.first?.rootViewController {
                var topController = rootViewController
                while let presented = topController.presentedViewController {
                    topController = presented
                }
                
                // Only proceed if picker isn't already presented
                if !(topController.presentedViewController is UIDocumentPickerViewController) {
                    // Set flag immediately to prevent duplicate presentations
                    coordinator.hasPresented = true
                    
                    // Present immediately (we're already on main thread)
                    let picker = UIDocumentPickerViewController(forOpeningContentTypes: allowedContentTypes, asCopy: true)
                    picker.delegate = coordinator
                    picker.allowsMultipleSelection = false
                    topController.present(picker, animated: true)
                }
            }
        } else if !isPresented {
            // Reset flag when isPresented becomes false
            coordinator.hasPresented = false
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
}

#Preview {
    ManageView()
}

