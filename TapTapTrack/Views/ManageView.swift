//
//  ManageView.swift
//  Tap Tap Track
//

import SwiftUI
import SwiftData

struct ManageView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Category.order) private var categories: [Category]
    @Query(sort: \EventPreset.createdAt) private var presets: [EventPreset]
    
    @State private var showingAddCategory = false
    @State private var showingAddPreset = false
    @State private var showingAbout = false
    @State private var categoryToEdit: Category?
    @State private var presetToEdit: EventPreset?
    @State private var presetToDelete: EventPreset?
    @State private var showingDeleteConfirmation = false
    
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
                        categories: categories,
                        onAdd: { showingAddCategory = true },
                        onEdit: { category in
                            categoryToEdit = category
                        },
                        onDelete: deleteCategory,
                        onMove: reorderCategories
                    )
                    
                    // Event Presets Section
                    PresetsSection(
                        presets: presets,
                        onAdd: { showingAddPreset = true },
                        onEdit: { preset in
                            presetToEdit = preset
                        },
                        onDelete: { preset in
                            presetToDelete = preset
                            showingDeleteConfirmation = true
                        }
                    )
                    
                    // About & Help Section
                    AboutSection(onTap: { showingAbout = true })
                    
                    Spacer(minLength: 100)
                }
            }
            
            // Floating Action Button
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    FloatingActionButton {
                        showingAddPreset = true
                    }
                    .padding(.trailing, 20)
                    .padding(.bottom, 100)
                }
            }
        }
        .sheet(isPresented: $showingAddCategory) {
            AddCategorySheet { name, locationTrackingEnabled in
                addCategory(name: name, locationTrackingEnabled: locationTrackingEnabled)
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $categoryToEdit) { category in
            EditCategorySheet(category: category) { name, locationTrackingEnabled in
                updateCategory(category, name: name, locationTrackingEnabled: locationTrackingEnabled)
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingAddPreset) {
            AddPresetSheet(categories: categories) { name, iconName, colorHex, category in
                addPreset(name: name, iconName: iconName, colorHex: colorHex, category: category)
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $presetToEdit) { preset in
            EditPresetSheet(preset: preset, categories: categories) { name, iconName, colorHex, category in
                updatePreset(preset, name: name, iconName: iconName, colorHex: colorHex, category: category)
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingAbout) {
            AboutSheet()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .confirmationDialog(
            "Delete \"\(presetToDelete?.name ?? "Preset")\"?",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Preset & All Events", role: .destructive) {
                if let preset = presetToDelete {
                    deletePresetAndEvents(preset)
                }
                presetToDelete = nil
            }
            
            Button("Delete Preset Only", role: .destructive) {
                if let preset = presetToDelete {
                    deletePresetKeepEvents(preset)
                }
                presetToDelete = nil
            }
            
            Button("Cancel", role: .cancel) {
                presetToDelete = nil
            }
        } message: {
            let eventCount = presetToDelete?.trackedEvents?.count ?? 0
            if eventCount > 0 {
                Text("This preset has \(eventCount) tracked event\(eventCount == 1 ? "" : "s"). You can delete everything, or keep the events and only remove the preset.")
            } else {
                Text("This will remove the preset. No tracked events are associated with it.")
            }
        }
    }
    
    private func addCategory(name: String, locationTrackingEnabled: Bool = false) {
        // Set order to be after the last category
        let maxOrder = categories.map { $0.order }.max() ?? -1
        let category = Category(name: name, locationTrackingEnabled: locationTrackingEnabled, order: maxOrder + 1)
        modelContext.insert(category)
        hapticFeedback()
    }
    
    private func deleteCategory(_ category: Category) {
        modelContext.delete(category)
        hapticFeedback()
    }
    
    private func updateCategory(_ category: Category, name: String, locationTrackingEnabled: Bool) {
        category.name = name
        category.locationTrackingEnabled = locationTrackingEnabled
        hapticFeedback()
    }
    
    private func addPreset(name: String, iconName: String, colorHex: String, category: Category?) {
        let preset = EventPreset(name: name, iconName: iconName, colorHex: colorHex, category: category)
        modelContext.insert(preset)
        hapticFeedback()
    }
    
    private func updatePreset(_ preset: EventPreset, name: String, iconName: String, colorHex: String, category: Category?) {
        preset.name = name
        preset.iconName = iconName
        preset.colorHex = colorHex
        preset.category = category
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
    
    private func reorderCategories(from source: IndexSet, to destination: Int) {
        var reorderedCategories = categories
        
        // Move items
        reorderedCategories.move(fromOffsets: source, toOffset: destination)
        
        // Update order values
        for (index, category) in reorderedCategories.enumerated() {
            category.order = index
        }
        
        hapticFeedback()
    }
    
    private func hapticFeedback() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
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
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(
                            top: 0,
                            leading: 20,
                            bottom: 12,
                            trailing: editMode == .active ? 16 : 20
                        ))
                    }
                    .onMove(perform: editMode == .active ? onMove : nil)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .environment(\.editMode, $editMode)
                .frame(height: CGFloat(categories.count) * 72 + 20)
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
            // Category name and location indicator
            HStack(spacing: 8) {
                Text(category.name)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                
                // Location enabled checkbox
                if category.locationTrackingEnabled {
                    Image(systemName: "location.fill")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "#60A5FA")!)
                }
            }
            
            Spacer()
            
            // Edit button (hidden in edit mode)
            if !showDragHandle {
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .font(.system(size: 16))
                        .foregroundColor(Color(hex: "#60A5FA")!)
                }
                .padding(.trailing, 8)
            }
            
            // Delete button (hidden in edit mode)
            if !showDragHandle {
                Button(action: onDelete) {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 16))
                        .foregroundColor(Color(hex: "#EF4444")!)
                }
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
                Text(preset.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                
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
    @StateObject private var locationManager = LocationManager()
    @State private var categoryName = ""
    @State private var locationTrackingEnabled = false
    @State private var showingPermissionAlert = false
    let onSave: (String, Bool) -> Void
    
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
                    
                    // Location tracking toggle
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "location.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.gray)
                            
                            Text("Enable Location Tracking")
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
                        
                        Text("When enabled, events in this category will automatically capture your location and nearby business names.")
                            .font(.system(size: 13))
                            .foregroundColor(.gray)
                    }
                    .padding()
                    .background(Color(hex: "#252540")!)
                    .cornerRadius(16)
                    .padding(.horizontal)
                    
                    HStack(spacing: 16) {
                        Button("Cancel") {
                            dismiss()
                        }
                        .buttonStyle(SecondaryButtonStyle())
                        
                        Button("Create") {
                            if !categoryName.isEmpty {
                                onSave(categoryName, locationTrackingEnabled)
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
    let onSave: (String, Bool) -> Void
    
    @StateObject private var locationManager = LocationManager()
    @State private var categoryName: String
    @State private var locationTrackingEnabled: Bool
    
    init(category: Category, onSave: @escaping (String, Bool) -> Void) {
        self.category = category
        self.onSave = onSave
        _categoryName = State(initialValue: category.name)
        _locationTrackingEnabled = State(initialValue: category.locationTrackingEnabled)
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
                    
                    // Location tracking toggle
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "location.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.gray)
                            
                            Text("Enable Location Tracking")
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
                        
                        Text("When enabled, events in this category will automatically capture your location and nearby business names.")
                            .font(.system(size: 13))
                            .foregroundColor(.gray)
                    }
                    .padding()
                    .background(Color(hex: "#252540")!)
                    .cornerRadius(16)
                    .padding(.horizontal)
                    
                    HStack(spacing: 16) {
                        Button("Cancel") {
                            dismiss()
                        }
                        .buttonStyle(SecondaryButtonStyle())
                        
                        Button("Save") {
                            if !categoryName.isEmpty {
                                onSave(categoryName, locationTrackingEnabled)
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
    let onSave: (String, String, String, Category?) -> Void
    
    @State private var presetName = ""
    @State private var selectedIcon = "star.fill"
    @State private var selectedColorHex = "#667eea"
    @State private var selectedCategory: Category?
    
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
                        
                        HStack(spacing: 16) {
                            Button("Cancel") {
                                dismiss()
                            }
                            .buttonStyle(SecondaryButtonStyle())
                            
                            Button("Create") {
                                if !presetName.isEmpty {
                                    onSave(presetName, selectedIcon, selectedColorHex, selectedCategory)
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
    let onSave: (String, String, String, Category?) -> Void
    
    @State private var presetName: String
    @State private var selectedIcon: String
    @State private var selectedColorHex: String
    @State private var selectedCategory: Category?
    
    init(preset: EventPreset, categories: [Category], onSave: @escaping (String, String, String, Category?) -> Void) {
        self.preset = preset
        self.categories = categories
        self.onSave = onSave
        _presetName = State(initialValue: preset.name)
        _selectedIcon = State(initialValue: preset.iconName)
        _selectedColorHex = State(initialValue: preset.colorHex ?? "#667eea")
        _selectedCategory = State(initialValue: preset.category)
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
                        
                        HStack(spacing: 16) {
                            Button("Cancel") {
                                dismiss()
                            }
                            .buttonStyle(SecondaryButtonStyle())
                            
                            Button("Save") {
                                if !presetName.isEmpty {
                                    onSave(presetName, selectedIcon, selectedColorHex, selectedCategory)
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
                                title: "Location Tracking",
                                description: "Enable location tracking for categories to automatically capture GPS coordinates and nearby business names when tracking events."
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
                        Text("Version 1.2")
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

#Preview {
    ManageView()
}

