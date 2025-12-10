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
    @State private var showingEditPreset = false
    @State private var selectedPreset: EventPreset?
    
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
                            selectedPreset = preset
                            showingEditPreset = true
                        },
                        onDelete: deletePreset
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
        .sheet(isPresented: $showingEditPreset) {
            if let preset = selectedPreset {
                EditPresetSheet(preset: preset, categories: categories) { name, iconName, category in
                    updatePreset(preset, name: name, iconName: iconName, category: category)
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
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
    
    private let columns = [
        GridItem(.adaptive(minimum: 50), spacing: 12)
    ]
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(EventPreset.availableIcons, id: \.systemName) { icon in
                Button {
                    selectedIcon = icon.systemName
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(selectedIcon == icon.systemName 
                                  ? Color(hex: "#667eea")! 
                                  : Color(hex: "#2a2a4e")!)
                            .frame(width: 50, height: 50)
                        
                        Image(systemName: icon.systemName)
                            .font(.system(size: 22))
                            .foregroundColor(.white)
                    }
                }
            }
        }
        .padding(.horizontal)
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

#Preview {
    ManageView()
}

