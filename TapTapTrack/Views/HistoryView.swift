//
//  HistoryView.swift
//  Tap Tap Track
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TrackedEvent.timestamp, order: .reverse) private var allEvents: [TrackedEvent]
    
    @State private var exportURL: ExportURL?
    @State private var eventToEdit: TrackedEvent?
    @State private var searchText: String = ""
    @State private var debouncedSearchText: String = ""
    @State private var isExporting: Bool = false
    @State private var eventToDelete: TrackedEvent?
    @State private var showDateFilter: Bool = false
    @State private var startDate: Date?
    @State private var endDate: Date?
    
    // Cached DateFormatter for better performance
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()
    
    private var filteredEvents: [TrackedEvent] {
        // Start with all events - search across everything
        var filtered = allEvents
        
        // Apply date range filter if set
        if let startDate = startDate {
            let calendar = Calendar.current
            let startOfDay = calendar.startOfDay(for: startDate)
            filtered = filtered.lazy.filter { $0.timestamp >= startOfDay }
        }
        
        if let endDate = endDate {
            let calendar = Calendar.current
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: endDate)) ?? endDate
            filtered = filtered.lazy.filter { $0.timestamp < endOfDay }
        }
        
        // Apply keyword search filter if set
        if !debouncedSearchText.isEmpty {
            let searchLower = debouncedSearchText.lowercased()
            filtered = filtered.lazy.filter { event in
                event.eventName.lowercased().contains(searchLower) ||
                event.categoryName.lowercased().contains(searchLower) ||
                (event.notes?.lowercased().contains(searchLower) ?? false)
            }
        }
        
        return Array(filtered)
    }
    
    private var hasActiveFilters: Bool {
        !debouncedSearchText.isEmpty || startDate != nil || endDate != nil
    }
    
    // Helper computed properties for DatePicker bindings to simplify type checking
    private var startDateBinding: Binding<Date> {
        Binding(
            get: {
                if let start = startDate {
                    return start
                }
                // Default to oldest event date or today
                let oldestDate = allEvents.last?.timestamp ?? Date()
                return oldestDate
            },
            set: { newValue in
                withAnimation {
                    startDate = newValue
                }
            }
        )
    }
    
    private var endDateBinding: Binding<Date> {
        Binding(
            get: {
                if let end = endDate {
                    return end
                }
                // Default to newest event date or today
                let newestDate = allEvents.first?.timestamp ?? Date()
                return newestDate
            },
            set: { newValue in
                withAnimation {
                    endDate = newValue
                }
            }
        )
    }
    
    // Optimized stats calculation - only compute when events change
    private var eventsToday: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        // Use lazy evaluation - only count what we need
        return allEvents.lazy.filter { calendar.isDate($0.timestamp, inSameDayAs: today) }.count
    }
    
    private var eventsThisWeek: Int {
        let calendar = Calendar.current
        let now = Date()
        guard let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) else {
            return 0
        }
        // Use lazy evaluation for better performance
        return allEvents.lazy.filter { $0.timestamp >= weekStart }.count
    }
    
    private var groupedEvents: [(date: String, events: [TrackedEvent])] {
        let grouped = Dictionary(grouping: filteredEvents) { event -> String in
            // Use cached formatter instead of creating new one each time
            return Self.dateFormatter.string(from: event.timestamp)
        }
        
        return grouped.map { (date: $0.key, events: $0.value) }
            .sorted { first, second in
                guard let firstEvent = first.events.first,
                      let secondEvent = second.events.first else {
                    return false
                }
                return firstEvent.timestamp > secondEvent.timestamp
            }
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
                    
                    // History Section
                    VStack(alignment: .leading, spacing: 20) {
                        // Header with Export button
                        HStack {
                            Text("Event History")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.white)
                            
                            Spacer()
                            
                            Button(action: exportToCSV) {
                                ZStack {
                                    HStack(spacing: 6) {
                                        Image(systemName: "arrow.down.doc.fill")
                                        Text(isExporting ? "Exporting..." : "Export")
                                    }
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white)
                                    .opacity(isExporting ? 0.3 : 1.0)
                                    
                                    if isExporting {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                            .scaleEffect(1.2)
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(
                                    LinearGradient(
                                        colors: [Color(hex: "#667eea")!, Color(hex: "#764ba2")!],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(20)
                                .animation(.easeInOut(duration: 0.2), value: isExporting)
                            }
                            .disabled(isExporting)
                            .animation(.easeInOut(duration: 0.2), value: isExporting)
                        }
                        .padding(.horizontal, 20)
                        
                        // Search Bar
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.gray)
                                .padding(.leading, 16)
                            
                            TextField("Search events, categories, or notes...", text: $searchText)
                                .textFieldStyle(PlainTextFieldStyle())
                                .foregroundColor(.white)
                                .padding(.vertical, 12)
                            
                            if !searchText.isEmpty {
                                Button(action: {
                                    searchText = ""
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.gray)
                                        .padding(.trailing, 16)
                                }
                            }
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(hex: "#2a2a4e")!)
                        )
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        
                        // Date Range Filter
                        VStack(spacing: 12) {
                            HStack {
                                Button(action: {
                                    withAnimation {
                                        showDateFilter.toggle()
                                    }
                                }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "calendar")
                                            .font(.system(size: 14))
                                        Text("Date Range")
                                            .font(.system(size: 14, weight: .medium))
                                        
                                        if startDate != nil || endDate != nil {
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.system(size: 12))
                                                .foregroundColor(Color(hex: "#10B981")!)
                                        }
                                        
                                        Spacer()
                                        
                                        Image(systemName: showDateFilter ? "chevron.up" : "chevron.down")
                                            .font(.system(size: 12))
                                    }
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .background(Color(hex: "#2a2a4e")!)
                                    .cornerRadius(12)
                                }
                                
                                if hasActiveFilters {
                                    Button(action: {
                                        withAnimation {
                                            searchText = ""
                                            debouncedSearchText = ""
                                            startDate = nil
                                            endDate = nil
                                        }
                                    }) {
                                        Text("Clear All")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(Color(hex: "#EF4444")!)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 10)
                                            .background(Color(hex: "#2a2a4e")!)
                                            .cornerRadius(12)
                                    }
                                }
                            }
                            
                            if showDateFilter {
                                VStack(spacing: 16) {
                                    // Start Date
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Start Date")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(.gray)
                                        
                                        HStack {
                                            if let startDate = startDate {
                                                Text(Self.dateFormatter.string(from: startDate))
                                                    .font(.system(size: 14))
                                                    .foregroundColor(.white)
                                                
                                                Button(action: {
                                                    withAnimation {
                                                        self.startDate = nil
                                                    }
                                                }) {
                                                    Image(systemName: "xmark.circle.fill")
                                                        .foregroundColor(.gray)
                                                }
                                            } else {
                                                Text("No start date")
                                                    .font(.system(size: 14))
                                                    .foregroundColor(.gray)
                                            }
                                            
                                            Spacer()
                                            
                                            DatePicker("", selection: startDateBinding, displayedComponents: .date)
                                            .datePickerStyle(.compact)
                                            .labelsHidden()
                                            .tint(Color(hex: "#667eea")!)
                                        }
                                        .padding()
                                        .background(Color(hex: "#252540")!)
                                        .cornerRadius(12)
                                    }
                                    
                                    // End Date
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("End Date")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(.gray)
                                        
                                        HStack {
                                            if let endDate = endDate {
                                                Text(Self.dateFormatter.string(from: endDate))
                                                    .font(.system(size: 14))
                                                    .foregroundColor(.white)
                                                
                                                Button(action: {
                                                    withAnimation {
                                                        self.endDate = nil
                                                    }
                                                }) {
                                                    Image(systemName: "xmark.circle.fill")
                                                        .foregroundColor(.gray)
                                                }
                                            } else {
                                                Text("No end date")
                                                    .font(.system(size: 14))
                                                    .foregroundColor(.gray)
                                            }
                                            
                                            Spacer()
                                            
                                            DatePicker("", selection: endDateBinding, displayedComponents: .date)
                                            .datePickerStyle(.compact)
                                            .labelsHidden()
                                            .tint(Color(hex: "#667eea")!)
                                        }
                                        .padding()
                                        .background(Color(hex: "#252540")!)
                                        .cornerRadius(12)
                                    }
                                    
                                    // Quick date range buttons
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Quick Filters")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(.gray)
                                        
                                        HStack(spacing: 8) {
                                            QuickDateButton(title: "Today", isActive: isTodaySelected) {
                                                let calendar = Calendar.current
                                                let today = calendar.startOfDay(for: Date())
                                                startDate = today
                                                endDate = today
                                            }
                                            
                                            QuickDateButton(title: "This Week", isActive: isThisWeekSelected) {
                                                let calendar = Calendar.current
                                                let now = Date()
                                                guard let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) else { return }
                                                startDate = weekStart
                                                endDate = now
                                            }
                                            
                                            QuickDateButton(title: "This Month", isActive: isThisMonthSelected) {
                                                let calendar = Calendar.current
                                                let now = Date()
                                                guard let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) else { return }
                                                startDate = monthStart
                                                endDate = now
                                            }
                                            
                                            QuickDateButton(title: "This Year", isActive: isThisYearSelected) {
                                                let calendar = Calendar.current
                                                let now = Date()
                                                guard let yearStart = calendar.date(from: calendar.dateComponents([.year], from: now)) else { return }
                                                startDate = yearStart
                                                endDate = now
                                            }
                                        }
                                    }
                                }
                                .padding()
                                .background(Color(hex: "#252540")!)
                                .cornerRadius(16)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        
                        if allEvents.isEmpty {
                            EmptyHistoryView()
                        } else if filteredEvents.isEmpty && hasActiveFilters {
                            EmptySearchResultsView()
                        } else {
                            // Grouped events - use LazyVStack for better performance with large datasets
                            LazyVStack(alignment: .leading, spacing: 0) {
                                ForEach(groupedEvents, id: \.date) { group in
                                    EventDateGroup(
                                        date: group.date,
                                        events: group.events,
                                        onTap: { event in
                                            eventToEdit = event
                                        },
                                        onEdit: { event in
                                            eventToEdit = event
                                        },
                                        onDelete: { event in
                                            eventToDelete = event
                                        }
                                    )
                                }
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
        .sheet(item: $exportURL) { exportURL in
            ShareSheet(activityItems: [exportURL.url])
        }
        .sheet(item: $eventToEdit) { event in
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
        .onChange(of: searchText) { oldValue, newValue in
            // Debounce search to avoid filtering on every keystroke
            let currentSearchText = newValue
            Task {
                try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 second delay
                // Only update if search text hasn't changed during the delay
                await MainActor.run {
                    if searchText == currentSearchText {
                        debouncedSearchText = currentSearchText
                    }
                }
            }
        }
        .onAppear {
            debouncedSearchText = searchText
        }
        .onChange(of: startDate) { oldValue, newValue in
            // Ensure end date is not before start date
            if let start = newValue, let end = endDate, end < start {
                endDate = start
            }
        }
        .onChange(of: endDate) { oldValue, newValue in
            // Ensure start date is not after end date
            if let end = newValue, let start = startDate, start > end {
                startDate = end
            }
        }
        .confirmationDialog(
            "Delete Event?",
            isPresented: Binding(
                get: { eventToDelete != nil },
                set: { if !$0 { eventToDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let event = eventToDelete {
                    deleteEvent(event)
                    eventToDelete = nil
                }
            }
            Button("Cancel", role: .cancel) {
                eventToDelete = nil
            }
        } message: {
            if let event = eventToDelete {
                Text("Are you sure you want to delete \"\(event.eventName)\"? This action cannot be undone.")
            }
        }
    }
    
    // Helper computed properties for quick date buttons
    private var isTodaySelected: Bool {
        guard let start = startDate, let end = endDate else { return false }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let startOfDay = calendar.startOfDay(for: start)
        let endOfDay = calendar.startOfDay(for: end)
        return startOfDay == today && endOfDay == today
    }
    
    private var isThisWeekSelected: Bool {
        guard let start = startDate, let end = endDate else { return false }
        let calendar = Calendar.current
        let now = Date()
        guard let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) else {
            return false
        }
        let startOfDay = calendar.startOfDay(for: start)
        return startOfDay == weekStart && abs(end.timeIntervalSince(now)) < 86400 // Within 24 hours
    }
    
    private var isThisMonthSelected: Bool {
        guard let start = startDate, let end = endDate else { return false }
        let calendar = Calendar.current
        let now = Date()
        guard let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) else {
            return false
        }
        let startOfDay = calendar.startOfDay(for: start)
        return startOfDay == monthStart && abs(end.timeIntervalSince(now)) < 86400 // Within 24 hours
    }
    
    private var isThisYearSelected: Bool {
        guard let start = startDate, let end = endDate else { return false }
        let calendar = Calendar.current
        let now = Date()
        guard let yearStart = calendar.date(from: calendar.dateComponents([.year], from: now)) else {
            return false
        }
        let startOfDay = calendar.startOfDay(for: start)
        return startOfDay == yearStart && abs(end.timeIntervalSince(now)) < 86400 // Within 24 hours
    }
    
    private func hapticFeedback() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }
    
    private func deleteEvent(_ event: TrackedEvent) {
        withAnimation {
            modelContext.delete(event)
            
            // Haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
        }
    }
    
    private func exportToCSV() {
        // Immediate feedback - ensure UI updates first
        hapticFeedback()
        
        // Use withAnimation to ensure state change is visible
        withAnimation(.easeInOut(duration: 0.2)) {
            isExporting = true
        }
        
        // Capture events on main thread before background work
        let eventsToExport = allEvents
        
        // Generate CSV on background thread to avoid blocking UI
        Task.detached(priority: .userInitiated) {
            // Small delay to ensure UI state is visible before heavy work
            try? await Task.sleep(nanoseconds: 150_000_000) // 0.15 seconds to show feedback
            
            let csvString = HistoryView.generateCSV(from: eventsToExport)
            
            // Use caches directory which is more reliable for sharing
            let cacheDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
            let fileName = "taptaptrack_export_\(Date().ISO8601Format()).csv"
            let fileURL = cacheDirectory.appendingPathComponent(fileName)
            
            do {
                // Remove old file if it exists
                if FileManager.default.fileExists(atPath: fileURL.path) {
                    try FileManager.default.removeItem(at: fileURL)
                }
                
                try csvString.write(to: fileURL, atomically: true, encoding: .utf8)
                
                // Ensure file is accessible
                var resourceValues = URLResourceValues()
                resourceValues.isExcludedFromBackup = true
                var mutableFileURL = fileURL
                try? mutableFileURL.setResourceValues(resourceValues)
                
                // Update UI on main thread
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        self.isExporting = false
                    }
                    // Setting exportURL will automatically present the sheet via .sheet(item:)
                    self.exportURL = ExportURL(url: fileURL)
                }
            } catch {
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        self.isExporting = false
                    }
                    print("Failed to export CSV: \(error)")
                }
            }
        }
    }
    
    nonisolated private static func generateCSV(from events: [TrackedEvent]) -> String {
        var csv = "Date,Time,Event,Category,Icon,Color,Notes,Latitude,Longitude,Location Name,Address\n"
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        
        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short
        
        for event in events {
            let date = dateFormatter.string(from: event.timestamp)
            let time = timeFormatter.string(from: event.timestamp)
            let eventName = event.eventName.replacingOccurrences(of: ",", with: ";")
            let category = event.categoryName.replacingOccurrences(of: ",", with: ";")
            let iconName = event.iconName.replacingOccurrences(of: ",", with: ";")
            let colorHex = (event.colorHex ?? "").replacingOccurrences(of: ",", with: ";")
            let notes = (event.notes ?? "").replacingOccurrences(of: ",", with: ";").replacingOccurrences(of: "\n", with: " ")
            let latitude = event.latitude != nil ? String(event.latitude!) : ""
            let longitude = event.longitude != nil ? String(event.longitude!) : ""
            let locationName = (event.locationName ?? "").replacingOccurrences(of: ",", with: ";")
            let address = (event.address ?? "").replacingOccurrences(of: ",", with: ";").replacingOccurrences(of: "\n", with: " ")
            
            csv += "\(date),\(time),\(eventName),\(category),\(iconName),\(colorHex),\"\(notes)\",\(latitude),\(longitude),\"\(locationName)\",\"\(address)\"\n"
        }
        
        return csv
    }
}

// MARK: - Empty History View
struct EmptyHistoryView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            
            Text("No events tracked yet")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.gray)
            
            Text("Tap an event preset to start tracking!")
                .font(.system(size: 14))
                .foregroundColor(.gray.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

// MARK: - Empty Search Results View
struct EmptySearchResultsView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            
            Text("No results found")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.gray)
            
            Text("Try a different search term")
                .font(.system(size: 14))
                .foregroundColor(.gray.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

// MARK: - Event Date Group
struct EventDateGroup: View {
    let date: String
    let events: [TrackedEvent]
    let onTap: (TrackedEvent) -> Void
    let onEdit: (TrackedEvent) -> Void
    let onDelete: (TrackedEvent) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(date)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.gray)
                .padding(.horizontal, 20)
            
            ForEach(events) { event in
                EventHistoryCard(
                    event: event,
                    onTap: { onTap(event) },
                    onEdit: { onEdit(event) },
                    onDelete: { onDelete(event) }
                )
                .padding(.horizontal, 20)
            }
        }
        .padding(.bottom, 16)
    }
}

// MARK: - Event History Card
struct EventHistoryCard: View {
    let event: TrackedEvent
    let onTap: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(event.color.opacity(0.2))
                    .frame(width: 44, height: 44)
                
                Image(systemName: event.iconName)
                    .font(.system(size: 18))
                    .foregroundColor(event.color)
            }
            
            // Event info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(event.eventName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text(event.categoryName)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color(hex: "#3a3a5e")!)
                        .cornerRadius(8)
                }
                
                // Location name (prominently displayed)
                if let locationName = event.locationName, !locationName.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "#60A5FA")!)
                        
                        Text(locationName)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(Color(hex: "#60A5FA")!)
                    }
                    .padding(.top, 2)
                }
                
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                    
                    Text(event.formattedTime)
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                }
                
                if let notes = event.notes, !notes.isEmpty {
                    Text("\"\(notes)\"")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(.gray)
                        .italic()
                        .lineLimit(2)
                }
            }
            
            Spacer()
            
            // Edit button
            Button(action: onEdit) {
                Image(systemName: "pencil")
                    .font(.system(size: 16))
                    .foregroundColor(Color(hex: "#60A5FA")!)
            }
            .padding(.trailing, 4)
            
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
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }
}

// MARK: - Export URL Wrapper
struct ExportURL: Identifiable {
    let id = UUID()
    let url: URL
}

// MARK: - Quick Date Button
struct QuickDateButton: View {
    let title: String
    let isActive: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(isActive ? .white : .gray)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isActive ? Color(hex: "#667eea")! : Color(hex: "#3a3a5e")!)
                )
        }
    }
}

// MARK: - Share Sheet
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        
        // Configure for better file sharing
        if activityItems.first is URL {
            controller.excludedActivityTypes = []
        }
        
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    HistoryView()
}

