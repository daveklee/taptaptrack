//
//  TrackView.swift
//  Tap Tap Track
//

import SwiftUI
import SwiftData

struct TrackView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Category.order) private var categories: [Category]
    @Query(sort: \EventPreset.name) private var presets: [EventPreset]
    @Query(sort: \TrackedEvent.timestamp, order: .reverse) private var allEvents: [TrackedEvent]
    
    // Location manager
    @StateObject private var locationManager = LocationManager()
    
    // Sheet item states - using separate state for each sheet type
    @State private var eventForConfirmation: TrackedEvent?
    @State private var eventForQuickNote: TrackedEvent?
    @State private var eventForEdit: TrackedEvent?
    @State private var presetForEdit: EventPreset?
    @State private var isCapturingLocation = false
    @State private var eventCapturingLocation: TrackedEvent?
    
    // Pending event from widget (optional for backward compatibility)
    @Binding var pendingEventID: UUID?
    
    init(pendingEventID: Binding<UUID?> = .constant(nil)) {
        self._pendingEventID = pendingEventID
    }
    
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

    private var visibleCategories: [Category] {
        categories.filter { !$0.isHiddenCategory }
    }

    private var uncategorizedPresets: [EventPreset] {
        presets
            .filter { $0.category == nil }
            .sorted { $0.name < $1.name }
    }
    
    var body: some View {
        ZStack {
            // Background gradient
            AppBackground()
            
            ScrollView {
                VStack(spacing: 0) {
                    // App Branding
                    HStack(spacing: 8) {
                        Image(systemName: "hand.tap.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white.opacity(0.9))
                        
                        Text("Tap Tap Track")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .padding(.top, 60)
                    .padding(.bottom, 16)
                    
                    // Stats Header
                    StatsHeader(
                        eventsToday: eventsToday,
                        eventsThisWeek: eventsThisWeek,
                        onTodayTap: switchToHistoryTab,
                        onWeekTap: switchToTrendsWeek
                    )
                        .padding(.bottom, 16)
                    
                    // Track Event Section
                    VStack(alignment: .leading, spacing: 20) {
                        HStack {
                            Text("Track Event")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.white)
                            
                            Spacer()
                            
                            Button(action: switchToManageTab) {
                                Label("Configure Taps", systemImage: "slider.horizontal.3")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(
                                        Capsule()
                                            .fill(Color.white.opacity(0.12))
                                            .overlay(
                                                Capsule()
                                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                            )
                                    )
                            }
                            .buttonStyle(PlainButtonStyle())
                            .accessibilityLabel("Update my taps")
                            .accessibilityHint("Opens manage page")
                        }
                        .padding(.horizontal, 20)
                        
                        // Categories with presets
                        ForEach(visibleCategories) { category in
                            let categoryPresets = (category.presets ?? []).sorted { $0.name < $1.name }
                            if !categoryPresets.isEmpty {
                                CategorySection(
                                    title: category.name,
                                    presets: categoryPresets,
                                    onTap: { preset in
                                        trackEvent(preset: preset)
                                    },
                                    onLongPress: { preset in
                                        editPreset(preset: preset)
                                    }
                                )
                            }
                        }

                        if !uncategorizedPresets.isEmpty {
                            CategorySection(
                                title: "Uncategorized",
                                presets: uncategorizedPresets,
                                onTap: { preset in
                                    trackEvent(preset: preset)
                                },
                                onLongPress: { preset in
                                    editPreset(preset: preset)
                                }
                            )
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
        .sheet(item: $eventForConfirmation) { event in
            TrackConfirmationSheet(
                event: event,
                isCapturingLocation: eventCapturingLocation?.id == event.id && isCapturingLocation,
                onAddNote: {
                    // Store event reference before confirmation dismisses
                    let eventToEdit = event
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        eventForQuickNote = eventToEdit
                    }
                },
                onEdit: {
                    // Store event reference before confirmation dismisses
                    let eventToEdit = event
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        self.eventForEdit = eventToEdit
                    }
                },
                onDelete: {
                    deleteEvent(event)
                }
            )
            .presentationDetents([.height(650)])
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $eventForQuickNote) { event in
            QuickNoteSheet(event: event) { notes in
                event.notes = notes
                hapticFeedback()
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $eventForEdit) { event in
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
        .sheet(item: $presetForEdit) { preset in
            EditPresetSheet(
                preset: preset,
                categories: categories
            ) { name, iconName, colorHex, category, numberEnabled, numberMin, numberMax, numberAllowDecimals, numberRequired, locationTrackingEnabled in
                updatePreset(
                    preset,
                    name: name,
                    iconName: iconName,
                    colorHex: colorHex,
                    category: category,
                    numberEnabled: numberEnabled,
                    numberMin: numberMin,
                    numberMax: numberMax,
                    numberAllowDecimals: numberAllowDecimals,
                    numberRequired: numberRequired,
                    locationTrackingEnabled: locationTrackingEnabled
                )
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .onAppear {
            // Handle pending event from widget
            if let eventID = pendingEventID {
                handlePendingEvent(eventID: eventID)
                DispatchQueue.main.async {
                    pendingEventID = nil
                }
            } else {
                // Also check for pending preset ID (from widget App Intent or deep link)
                // Add a small delay to ensure SwiftData is ready
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    handlePendingPresetID()
                }
            }
        }
        .onChange(of: pendingEventID) { oldValue, newValue in
            if let eventID = newValue {
                handlePendingEvent(eventID: eventID)
                DispatchQueue.main.async {
                    pendingEventID = nil
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            // Check for pending preset ID when app comes to foreground
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                handlePendingPresetID()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            // Also check when app becomes active (handles cold start from widget)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                handlePendingPresetID()
            }
        }
    }
    
    private func handlePendingEvent(eventID: UUID) {
        // Find the event that was created by the widget
        let descriptor = FetchDescriptor<TrackedEvent>(
            predicate: #Predicate<TrackedEvent> { $0.id == eventID }
        )
        
        if let event = try? modelContext.fetch(descriptor).first {
            // Show confirmation screen
            eventForConfirmation = event
            
            // If location is needed, start capturing
            let preset = event.preset
            let needsLocation = preset?.locationTrackingEnabled ?? false
            
            if needsLocation, let preset = preset {
                eventCapturingLocation = event
                Task {
                    await updateEventWithLocation(event: event, preset: preset)
                }
            }
        } else {
            // Event not found, might need to create it from preset ID
            // Check if we have a pending preset ID from widget or deep link
            handlePendingPresetID()
        }
    }
    
    private func handlePendingPresetID() {
        if let presetIDString = UserDefaults(suiteName: "group.com.taptaptrack")?.string(forKey: "pendingPresetID"),
           let presetID = UUID(uuidString: presetIDString) {
            let presetDescriptor = FetchDescriptor<EventPreset>(
                predicate: #Predicate<EventPreset> { $0.id == presetID }
            )
            
            if let preset = try? modelContext.fetch(presetDescriptor).first {
                trackEvent(preset: preset)
            }
            
            // Clear the stored preset ID
            UserDefaults(suiteName: "group.com.taptaptrack")?.removeObject(forKey: "pendingPresetID")
        }
    }
    
    private func trackEvent(preset: EventPreset, notes: String? = nil) {
        let needsLocation = preset.locationTrackingEnabled
        
        // Always provide immediate feedback
        hapticFeedback()
        
        if needsLocation {
            // Create event immediately without location
            let event = TrackedEvent(preset: preset, notes: notes)
            modelContext.insert(event)
            
            // Save context to ensure event is persisted before showing sheet
            try? modelContext.save()
            
            // Use DispatchQueue to ensure UI update happens after context save
            DispatchQueue.main.async {
                self.eventForConfirmation = event
                self.eventCapturingLocation = event
            }
            
            // Then update with location data asynchronously
            Task {
                await updateEventWithLocation(event: event, preset: preset)
            }
        } else {
            let event = TrackedEvent(preset: preset, notes: notes)
            modelContext.insert(event)
            
            // Save context to ensure event is persisted before showing sheet
            try? modelContext.save()
            
            // Use DispatchQueue to ensure UI update happens after context save
            DispatchQueue.main.async {
                self.eventForConfirmation = event
            }
        }
    }
    
    private func trackEventAndEdit(preset: EventPreset) {
        let needsLocation = preset.locationTrackingEnabled
        
        // Always provide immediate feedback
        hapticFeedback()
        
        if needsLocation {
            // Create event immediately without location
            let event = TrackedEvent(preset: preset)
            modelContext.insert(event)
            
            // Save context to ensure event is persisted before showing sheet
            try? modelContext.save()
            
            // Use DispatchQueue to ensure UI update happens after context save
            DispatchQueue.main.async {
                self.eventForEdit = event
                self.eventCapturingLocation = event
            }
            
            // Then update with location data asynchronously
            Task {
                await updateEventWithLocationAndEdit(event: event, preset: preset)
            }
        } else {
            let event = TrackedEvent(preset: preset)
            modelContext.insert(event)
            
            // Save context to ensure event is persisted before showing sheet
            try? modelContext.save()
            
            // Use DispatchQueue to ensure UI update happens after context save
            DispatchQueue.main.async {
                self.eventForEdit = event
            }
        }
    }

    private func editPreset(preset: EventPreset) {
        hapticFeedback()
        presetForEdit = preset
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
    
    private func updateEventWithLocation(event: TrackedEvent, preset: EventPreset) async {
        await MainActor.run {
            isCapturingLocation = true
        }
        
        // Check permission
        if locationManager.authorizationStatus == .notDetermined {
            locationManager.requestPermission()
            // Wait a bit for permission dialog
            try? await Task.sleep(nanoseconds: 500_000_000)
        }
        
        guard locationManager.authorizationStatus == .authorizedWhenInUse || locationManager.authorizationStatus == .authorizedAlways else {
            // Permission denied, keep event without location
            await MainActor.run {
                isCapturingLocation = false
                eventCapturingLocation = nil
            }
            return
        }
        
        do {
            // Get current location
            let location = try await locationManager.getCurrentLocation()
            
            // Search for nearby businesses
            var locationName: String? = nil
            var address: String? = nil
            
            do {
                let businesses = try await locationManager.searchNearbyBusinesses(at: location)
                if let nearestBusiness = businesses.first {
                    locationName = nearestBusiness.name
                }
            } catch {
                // If business search fails, try reverse geocoding
                locationName = try? await locationManager.reverseGeocode(location: location)
            }
            
            // Get address
            address = try? await locationManager.getAddress(from: location)
            
            // Update existing event with location data
            await MainActor.run {
                event.latitude = location.coordinate.latitude
                event.longitude = location.coordinate.longitude
                event.locationName = locationName
                event.address = address
                isCapturingLocation = false
                eventCapturingLocation = nil
            }
        } catch {
            // Location failed, keep event without location
            await MainActor.run {
                isCapturingLocation = false
                eventCapturingLocation = nil
            }
        }
    }
    
    private func updateEventWithLocationAndEdit(event: TrackedEvent, preset: EventPreset) async {
        await MainActor.run {
            isCapturingLocation = true
        }
        
        // Check permission
        if locationManager.authorizationStatus == .notDetermined {
            locationManager.requestPermission()
            // Wait a bit for permission dialog
            try? await Task.sleep(nanoseconds: 500_000_000)
        }
        
        guard locationManager.authorizationStatus == .authorizedWhenInUse || locationManager.authorizationStatus == .authorizedAlways else {
            // Permission denied, keep event without location
            await MainActor.run {
                isCapturingLocation = false
                eventCapturingLocation = nil
            }
            return
        }
        
        do {
            // Get current location
            let location = try await locationManager.getCurrentLocation()
            
            // Search for nearby businesses
            var locationName: String? = nil
            var address: String? = nil
            
            do {
                let businesses = try await locationManager.searchNearbyBusinesses(at: location)
                if let nearestBusiness = businesses.first {
                    locationName = nearestBusiness.name
                }
            } catch {
                // If business search fails, try reverse geocoding
                locationName = try? await locationManager.reverseGeocode(location: location)
            }
            
            // Get address
            address = try? await locationManager.getAddress(from: location)
            
            // Update existing event with location data
            await MainActor.run {
                event.latitude = location.coordinate.latitude
                event.longitude = location.coordinate.longitude
                event.locationName = locationName
                event.address = address
                isCapturingLocation = false
                eventCapturingLocation = nil
            }
        } catch {
            // Location failed, keep event without location
            await MainActor.run {
                isCapturingLocation = false
                eventCapturingLocation = nil
            }
        }
    }
    
    private func deleteEvent(_ event: TrackedEvent) {
        withAnimation {
            modelContext.delete(event)
            
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
        }
    }
    
    private func hapticFeedback() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }
    
    private func switchToHistoryTab() {
        NotificationCenter.default.post(
            name: NSNotification.Name("SwitchToHistoryTab"),
            object: nil
        )
    }
    
    private func switchToTrendsWeek() {
        UserDefaults.standard.set("week", forKey: "pendingTrendsTimeRange")
        NotificationCenter.default.post(
            name: NSNotification.Name("SwitchToTrendsTab"),
            object: nil
        )
    }
    
    private func switchToManageTab() {
        NotificationCenter.default.post(
            name: NSNotification.Name("SwitchToManageTab"),
            object: nil
        )
    }
}

// MARK: - Stats Header
struct StatsHeader: View {
    let eventsToday: Int
    let eventsThisWeek: Int
    let onTodayTap: () -> Void
    let onWeekTap: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            // Circular Progress
            Button(action: onTodayTap) {
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
                .contentShape(Circle())
            }
            .buttonStyle(PlainButtonStyle())
            .accessibilityLabel("View event history")
            
            // Stats Row
            HStack(spacing: 48) {
                Button(action: onTodayTap) {
                    StatItem(icon: "calendar", value: eventsToday, label: "Today")
                        .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
                .accessibilityLabel("View today's event history")
                
                Button(action: onWeekTap) {
                    StatItem(icon: "chart.bar.fill", value: eventsThisWeek, label: "This Week")
                        .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
                .accessibilityLabel("View trends for last week")
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

// MARK: - Update Taps Link
struct UpdateTapsLink: View {
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color(hex: "#60A5FA")!.opacity(0.2))
                        .frame(width: 38, height: 38)
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(hex: "#60A5FA")!)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Update my taps")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    Text("Add or remove categories and presets")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.7))
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(hex: "#1a1a2e")!.opacity(0.9))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.06), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.horizontal, 20)
        .accessibilityLabel("Update my taps")
        .accessibilityHint("Opens manage page")
    }
}

// MARK: - Category Section
struct CategorySection: View {
    let title: String
    let presets: [EventPreset]
    let onTap: (EventPreset) -> Void
    let onLongPress: (EventPreset) -> Void
    
    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.gray)
                .padding(.horizontal, 20)
            
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(presets) { preset in
                    EventPresetCard(
                        preset: preset,
                        onTap: {
                            onTap(preset)
                        },
                        onLongPress: {
                            onLongPress(preset)
                        }
                    )
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
    let onTap: () -> Void
    let onLongPress: () -> Void
    
    @State private var isPressed = false

    private var showsLocationBadge: Bool {
        preset.locationTrackingEnabled
    }

    private var showsNumberBadge: Bool {
        preset.numberEnabled
    }
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Card background
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [
                            preset.color,
                            preset.color.opacity(0.7)
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

            if showsLocationBadge || showsNumberBadge {
                HStack(spacing: 6) {
                    if showsLocationBadge {
                        Image(systemName: "location.fill")
                    }
                    if showsNumberBadge {
                        Image(systemName: "number")
                    }
                }
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white.opacity(0.9))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.black.opacity(0.25))
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .padding(8)
            }
            
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
        .onTapGesture {
            // Immediate visual feedback
            withAnimation(.spring(response: 0.2)) {
                isPressed = true
            }
            // Call the callback immediately
            onTap()
            // Reset visual feedback after animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.spring(response: 0.2)) {
                    isPressed = false
                }
            }
        }
        .onLongPressGesture(minimumDuration: 0.5) {
            // Immediate visual feedback for long press
            withAnimation(.spring(response: 0.2)) {
                isPressed = true
            }
            // Call the callback
            onLongPress()
            // Reset visual feedback after animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.spring(response: 0.2)) {
                    isPressed = false
                }
            }
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

