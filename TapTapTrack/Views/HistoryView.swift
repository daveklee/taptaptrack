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
    @State private var isExporting: Bool = false
    
    private var filteredEvents: [TrackedEvent] {
        if searchText.isEmpty {
            return allEvents
        }
        
        let searchLower = searchText.lowercased()
        return allEvents.filter { event in
            event.eventName.lowercased().contains(searchLower) ||
            event.categoryName.lowercased().contains(searchLower) ||
            (event.notes?.lowercased().contains(searchLower) ?? false)
        }
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
    
    private var groupedEvents: [(date: String, events: [TrackedEvent])] {
        let grouped = Dictionary(grouping: filteredEvents) { event -> String in
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return formatter.string(from: event.timestamp)
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
                        
                        if allEvents.isEmpty {
                            EmptyHistoryView()
                        } else if filteredEvents.isEmpty && !searchText.isEmpty {
                            EmptySearchResultsView()
                        } else {
                            // Grouped events
                            ForEach(groupedEvents, id: \.date) { group in
                                EventDateGroup(
                                    date: group.date,
                                    events: group.events,
                                    onEdit: { event in
                                        eventToEdit = event
                                    },
                                    onDelete: { event in
                                        deleteEvent(event)
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
    }
}

// MARK: - Export URL Wrapper
struct ExportURL: Identifiable {
    let id = UUID()
    let url: URL
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

