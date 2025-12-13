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
    
    @State private var showingExportSheet = false
    @State private var exportURL: URL?
    
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
        let grouped = Dictionary(grouping: allEvents) { event -> String in
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
                                HStack(spacing: 6) {
                                    Image(systemName: "arrow.down.doc.fill")
                                    Text("Export")
                                }
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
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
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        if allEvents.isEmpty {
                            EmptyHistoryView()
                        } else {
                            // Grouped events
                            ForEach(groupedEvents, id: \.date) { group in
                                EventDateGroup(date: group.date, events: group.events) { event in
                                    deleteEvent(event)
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
        .sheet(isPresented: $showingExportSheet) {
            if let url = exportURL {
                ShareSheet(activityItems: [url])
            }
        }
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
        let csvString = generateCSV()
        
        let tempDirectory = FileManager.default.temporaryDirectory
        let fileName = "taptaptrack_export_\(Date().ISO8601Format()).csv"
        let fileURL = tempDirectory.appendingPathComponent(fileName)
        
        do {
            try csvString.write(to: fileURL, atomically: true, encoding: .utf8)
            exportURL = fileURL
            showingExportSheet = true
        } catch {
            print("Failed to export CSV: \(error)")
        }
    }
    
    private func generateCSV() -> String {
        var csv = "Date,Time,Event,Category,Notes\n"
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        
        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short
        
        for event in allEvents {
            let date = dateFormatter.string(from: event.timestamp)
            let time = timeFormatter.string(from: event.timestamp)
            let eventName = event.eventName.replacingOccurrences(of: ",", with: ";")
            let category = event.categoryName.replacingOccurrences(of: ",", with: ";")
            let notes = (event.notes ?? "").replacingOccurrences(of: ",", with: ";").replacingOccurrences(of: "\n", with: " ")
            
            csv += "\(date),\(time),\(eventName),\(category),\"\(notes)\"\n"
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

// MARK: - Event Date Group
struct EventDateGroup: View {
    let date: String
    let events: [TrackedEvent]
    let onDelete: (TrackedEvent) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(date)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.gray)
                .padding(.horizontal, 20)
            
            ForEach(events) { event in
                EventHistoryCard(event: event, onDelete: { onDelete(event) })
                    .padding(.horizontal, 20)
            }
        }
        .padding(.bottom, 16)
    }
}

// MARK: - Event History Card
struct EventHistoryCard: View {
    let event: TrackedEvent
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(hex: "#2a2a4e")!)
                    .frame(width: 44, height: 44)
                
                Image(systemName: event.iconName)
                    .font(.system(size: 18))
                    .foregroundColor(Color(hex: "#60A5FA")!)
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

// MARK: - Share Sheet
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    HistoryView()
}

