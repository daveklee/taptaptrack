//
//  TrackView.swift
//  Tap Tap Track
//

import SwiftUI
import SwiftData

struct TrackView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Category.createdAt) private var categories: [Category]
    @Query(sort: \TrackedEvent.timestamp, order: .reverse) private var allEvents: [TrackedEvent]
    
    @State private var showingNoteSheet = false
    @State private var selectedPreset: EventPreset?
    @State private var noteText = ""
    
    // Confirmation states
    @State private var showingConfirmation = false
    @State private var showingQuickNote = false
    @State private var showingEditEvent = false
    @State private var trackedEvent: TrackedEvent?
    
    private var eventsToday: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return allEvents.filter { calendar.isDate($0.timestamp, inSameDayAs: today) }.count
    }
    
    private var eventsThisWeek: Int {
        let calendar = Calendar.current
        let now = Date()
        guard let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) else {
            return 0
        }
        return allEvents.filter { $0.timestamp >= weekStart }.count
    }
    
    var body: some View {
        ZStack {
            // Background gradient
            AppBackground()
            
            ScrollView {
                VStack(spacing: 0) {
                    // Stats Header
                    StatsHeader(eventsToday: eventsToday, eventsThisWeek: eventsThisWeek)
                        .padding(.top, 60)
                        .padding(.bottom, 24)
                    
                    // Track Event Section
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Track Event")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                        
                        // Categories with presets
                        ForEach(categories) { category in
                            if let presets = category.presets, !presets.isEmpty {
                                CategorySection(
                                    category: category,
                                    presets: presets,
                                    onTap: { preset in
                                        trackEvent(preset: preset)
                                    },
                                    onLongPress: { preset in
                                        selectedPreset = preset
                                        noteText = ""
                                        showingNoteSheet = true
                                    }
                                )
                            }
                        }
                    }
                    .padding(.vertical, 24)
                    .background(
                        RoundedRectangle(cornerRadius: 32)
                            .fill(Color(hex: "#1a1a2e")!.opacity(0.95))
                    )
                    
                    Spacer(minLength: 100)
                }
            }
        }
        .sheet(isPresented: $showingNoteSheet) {
            AddNoteSheet(
                presetName: selectedPreset?.name ?? "",
                noteText: $noteText,
                onSave: {
                    if let preset = selectedPreset {
                        trackEvent(preset: preset, notes: noteText.isEmpty ? nil : noteText)
                    }
                    showingNoteSheet = false
                },
                onCancel: {
                    showingNoteSheet = false
                }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingConfirmation) {
            if let event = trackedEvent {
                TrackConfirmationSheet(
                    event: event,
                    onAddNote: {
                        showingQuickNote = true
                    },
                    onEdit: {
                        showingEditEvent = true
                    },
                    onDelete: {
                        deleteEvent(event)
                    }
                )
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
            }
        }
        .sheet(isPresented: $showingQuickNote) {
            if let event = trackedEvent {
                QuickNoteSheet(event: event) { notes in
                    event.notes = notes
                    hapticFeedback()
                }
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
            }
        }
        .sheet(isPresented: $showingEditEvent) {
            if let event = trackedEvent {
                EditEventSheet(
                    event: event,
                    onSave: { newDate, notes in
                        event.timestamp = newDate
                        event.notes = notes
                        hapticFeedback()
                    },
                    onDelete: {
                        deleteEvent(event)
                    }
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
        }
    }
    
    private func trackEvent(preset: EventPreset, notes: String? = nil) {
        let event = TrackedEvent(preset: preset, notes: notes)
        modelContext.insert(event)
        
        // Store reference and show confirmation
        trackedEvent = event
        showingConfirmation = true
        
        // Haptic feedback
        hapticFeedback()
    }
    
    private func deleteEvent(_ event: TrackedEvent) {
        withAnimation {
            modelContext.delete(event)
            trackedEvent = nil
            
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
        }
    }
    
    private func hapticFeedback() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }
}

// MARK: - Stats Header
struct StatsHeader: View {
    let eventsToday: Int
    let eventsThisWeek: Int
    
    var body: some View {
        VStack(spacing: 24) {
            // Circular Progress
            ZStack {
                // Background circle
                Circle()
                    .stroke(Color.white.opacity(0.2), lineWidth: 12)
                    .frame(width: 180, height: 180)
                
                // Progress arc
                Circle()
                    .trim(from: 0, to: min(CGFloat(eventsToday) / 10.0, 1.0))
                    .stroke(
                        LinearGradient(
                            colors: [.white, .white.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .frame(width: 180, height: 180)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.6), value: eventsToday)
                
                // Center text
                VStack(spacing: 4) {
                    Text("\(eventsToday)")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(.white)
                    Text("Events Today")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            
            // Stats Row
            HStack(spacing: 48) {
                StatItem(icon: "calendar", value: eventsToday, label: "Today")
                StatItem(icon: "chart.bar.fill", value: eventsThisWeek, label: "This Week")
            }
        }
    }
}

struct StatItem: View {
    let icon: String
    let value: Int
    let label: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(.white.opacity(0.8))
            
            Text("\(value)")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
            
            Text(label)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.7))
        }
    }
}

// MARK: - Category Section
struct CategorySection: View {
    let category: Category
    let presets: [EventPreset]
    let onTap: (EventPreset) -> Void
    let onLongPress: (EventPreset) -> Void
    
    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(category.name)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.gray)
                .padding(.horizontal, 20)
            
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(presets) { preset in
                    EventPresetCard(preset: preset, category: category)
                        .onTapGesture {
                            onTap(preset)
                        }
                        .onLongPressGesture(minimumDuration: 0.5) {
                            onLongPress(preset)
                        }
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.bottom, 8)
    }
}

// MARK: - Event Preset Card
struct EventPresetCard: View {
    let preset: EventPreset
    let category: Category
    
    @State private var isPressed = false
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Card background
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: "#667eea")!,
                            Color(hex: "#764ba2")!
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            // Content
            VStack(spacing: 8) {
                Image(systemName: preset.iconName)
                    .font(.system(size: 32, weight: .medium))
                    .foregroundColor(.white)
                
                Text(preset.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
            
            // Plus button indicator
            Circle()
                .fill(Color.black.opacity(0.3))
                .frame(width: 28, height: 28)
                .overlay(
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                )
                .padding(8)
        }
        .frame(height: 110)
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.spring(response: 0.2), value: isPressed)
    }
}

// MARK: - Add Note Sheet
struct AddNoteSheet: View {
    let presetName: String
    @Binding var noteText: String
    let onSave: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "#1a1a2e")!.ignoresSafeArea()
                
                VStack(spacing: 20) {
                    Text("Add Note to \(presetName)")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                    
                    TextEditor(text: $noteText)
                        .scrollContentBackground(.hidden)
                        .background(Color(hex: "#2a2a4e")!)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .frame(height: 120)
                        .padding(.horizontal)
                    
                    HStack(spacing: 16) {
                        Button("Cancel") {
                            onCancel()
                        }
                        .buttonStyle(SecondaryButtonStyle())
                        
                        Button("Track Event") {
                            onSave()
                        }
                        .buttonStyle(PrimaryButtonStyle())
                    }
                    .padding(.horizontal)
                    
                    Spacer()
                }
                .padding(.top, 24)
            }
            .navigationBarHidden(true)
        }
    }
}

// MARK: - Button Styles
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                LinearGradient(
                    colors: [Color(hex: "#667eea")!, Color(hex: "#764ba2")!],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(12)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.white.opacity(0.8))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color(hex: "#2a2a4e")!)
            .cornerRadius(12)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
    }
}

#Preview {
    TrackView()
}

