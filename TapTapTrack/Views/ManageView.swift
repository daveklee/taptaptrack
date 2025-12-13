//
//  ManageView.swift
//  Tap Tap Track
//

import SwiftUI
import SwiftData

struct ManageView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Category.createdAt) private var categories: [Category]
    @Query(sort: \EventPreset.createdAt) private var presets: [EventPreset]
    
    @State private var showingAddCategory = false
    @State private var showingAddPreset = false
    @State private var showingAbout = false
    @State private var presetToEdit: EventPreset?
    
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
                        onDelete: deleteCategory
                    )
                    
                    // Event Presets Section
                    PresetsSection(
                        presets: presets,
                        onAdd: { showingAddPreset = true },
                        onEdit: { preset in
                            presetToEdit = preset
                        },
                        onDelete: deletePreset
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
            AddCategorySheet { name in
                addCategory(name: name)
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingAddPreset) {
            AddPresetSheet(categories: categories) { name, iconName, category in
                addPreset(name: name, iconName: iconName, category: category)
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $presetToEdit) { preset in
            EditPresetSheet(preset: preset, categories: categories) { name, iconName, category in
                updatePreset(preset, name: name, iconName: iconName, category: category)
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingAbout) {
            AboutSheet()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }
    
    private func addCategory(name: String) {
        let category = Category(name: name)
        modelContext.insert(category)
        hapticFeedback()
    }
    
    private func deleteCategory(_ category: Category) {
        modelContext.delete(category)
        hapticFeedback()
    }
    
    private func addPreset(name: String, iconName: String, category: Category?) {
        let preset = EventPreset(name: name, iconName: iconName, category: category)
        modelContext.insert(preset)
        hapticFeedback()
    }
    
    private func updatePreset(_ preset: EventPreset, name: String, iconName: String, category: Category?) {
        preset.name = name
        preset.iconName = iconName
        preset.category = category
        hapticFeedback()
    }
    
    private func deletePreset(_ preset: EventPreset) {
        modelContext.delete(preset)
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
    let onDelete: (Category) -> Void
    
    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Categories")
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
            
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(categories) { category in
                    CategoryCard(category: category, onDelete: { onDelete(category) })
                }
            }
            .padding(.horizontal, 20)
        }
    }
}

struct CategoryCard: View {
    let category: Category
    let onDelete: () -> Void
    
    var body: some View {
        HStack {
            Text(category.name)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
            
            Spacer()
            
            Button(action: onDelete) {
                Image(systemName: "trash.fill")
                    .font(.system(size: 16))
                    .foregroundColor(Color(hex: "#EF4444")!)
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
                    .fill(Color(hex: "#2a2a4e")!)
                    .frame(width: 44, height: 44)
                
                Image(systemName: preset.iconName)
                    .font(.system(size: 18))
                    .foregroundColor(Color(hex: "#60A5FA")!)
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

// MARK: - Add Preset Sheet
struct AddPresetSheet: View {
    @Environment(\.dismiss) private var dismiss
    let categories: [Category]
    let onSave: (String, String, Category?) -> Void
    
    @State private var presetName = ""
    @State private var selectedIcon = "star.fill"
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
                                    onSave(presetName, selectedIcon, selectedCategory)
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
    let onSave: (String, String, Category?) -> Void
    
    @State private var presetName: String
    @State private var selectedIcon: String
    @State private var selectedCategory: Category?
    
    init(preset: EventPreset, categories: [Category], onSave: @escaping (String, String, Category?) -> Void) {
        self.preset = preset
        self.categories = categories
        self.onSave = onSave
        _presetName = State(initialValue: preset.name)
        _selectedIcon = State(initialValue: preset.iconName)
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
                                    onSave(presetName, selectedIcon, selectedCategory)
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
                                description: "Use the Manage tab to create your own categories and event presets with custom icons."
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
                            TipItem(text: "Add notes to remember context about specific events")
                        }
                        .padding(20)
                        .background(Color(hex: "#252540")!)
                        .cornerRadius(20)
                        .padding(.horizontal, 20)
                        
                        // Version
                        Text("Version 1.0")
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

#Preview {
    ManageView()
}

