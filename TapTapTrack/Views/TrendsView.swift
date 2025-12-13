//
//  TrendsView.swift
//  Tap Tap Track
//

import SwiftUI
import SwiftData
import Charts

struct TrendsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TrackedEvent.timestamp, order: .reverse) private var allEvents: [TrackedEvent]
    @Query(sort: \Category.name) private var allCategories: [Category]
    @Query(sort: \EventPreset.name) private var allPresets: [EventPreset]
    
    @State private var selectedTimeRange: TimeRange = .week
    @State private var filterType: FilterType = .category
    @State private var selectedCategory: Category?
    @State private var selectedPreset: EventPreset?
    
    enum TimeRange: String, CaseIterable {
        case day = "1D"
        case week = "1W"
        case month = "1M"
        case threeMonths = "3M"
        case sixMonths = "6M"
        case year = "1Y"
        case all = "All"
        
        var dateRange: (start: Date, end: Date) {
            let calendar = Calendar.current
            let now = Date()
            
            switch self {
            case .day:
                let start = calendar.startOfDay(for: now)
                return (start, now)
            case .week:
                let start = calendar.date(byAdding: .day, value: -7, to: now) ?? now
                return (start, now)
            case .month:
                let start = calendar.date(byAdding: .month, value: -1, to: now) ?? now
                return (start, now)
            case .threeMonths:
                let start = calendar.date(byAdding: .month, value: -3, to: now) ?? now
                return (start, now)
            case .sixMonths:
                let start = calendar.date(byAdding: .month, value: -6, to: now) ?? now
                return (start, now)
            case .year:
                let start = calendar.date(byAdding: .year, value: -1, to: now) ?? now
                return (start, now)
            case .all:
                return (Date.distantPast, now)
            }
        }
    }
    
    enum FilterType: String, CaseIterable {
        case category = "Category"
        case preset = "Preset"
    }
    
    private var filteredEvents: [TrackedEvent] {
        let (startDate, endDate) = selectedTimeRange.dateRange
        var events = allEvents.filter { event in
            event.timestamp >= startDate && event.timestamp <= endDate
        }
        
        switch filterType {
        case .category:
            if let category = selectedCategory {
                events = events.filter { $0.categoryName == category.name }
            }
        case .preset:
            if let preset = selectedPreset {
                events = events.filter { $0.eventName == preset.name }
            }
        }
        
        return events
    }
    
    private var chartData: [ChartDataPoint] {
        let (startDate, endDate) = selectedTimeRange.dateRange
        let calendar = Calendar.current
        
        // Group events by appropriate interval
        let grouped: [Date: [TrackedEvent]]
        switch selectedTimeRange {
        case .day:
            grouped = Dictionary(grouping: filteredEvents) { event -> Date in
                let components = calendar.dateComponents([.year, .month, .day, .hour], from: event.timestamp)
                return calendar.date(from: components) ?? event.timestamp
            }
        case .week, .month:
            grouped = Dictionary(grouping: filteredEvents) { event -> Date in
                let components = calendar.dateComponents([.year, .month, .day], from: event.timestamp)
                return calendar.startOfDay(for: calendar.date(from: components) ?? event.timestamp)
            }
        case .threeMonths, .sixMonths:
            grouped = Dictionary(grouping: filteredEvents) { event -> Date in
                let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: event.timestamp)
                return calendar.date(from: components) ?? event.timestamp
            }
        case .year, .all:
            grouped = Dictionary(grouping: filteredEvents) { event -> Date in
                let components = calendar.dateComponents([.year, .month], from: event.timestamp)
                return calendar.date(from: components) ?? event.timestamp
            }
        }
        
        // Create data points for all intervals in the range
        var dataPoints: [ChartDataPoint] = []
        var seenKeys = Set<Date>()
        var currentDate = startDate
        
        while currentDate <= endDate {
            let key: Date
            switch selectedTimeRange {
            case .day:
                let components = calendar.dateComponents([.year, .month, .day, .hour], from: currentDate)
                key = calendar.date(from: components) ?? currentDate
            case .week, .month:
                key = calendar.startOfDay(for: currentDate)
            case .threeMonths, .sixMonths:
                let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: currentDate)
                key = calendar.date(from: components) ?? currentDate
            case .year, .all:
                let components = calendar.dateComponents([.year, .month], from: currentDate)
                key = calendar.date(from: components) ?? currentDate
            }
            
            // Only add if we haven't seen this key before
            if !seenKeys.contains(key) {
                seenKeys.insert(key)
                let count = grouped[key]?.count ?? 0
                dataPoints.append(ChartDataPoint(date: key, count: count))
            }
            
            // Move to next interval
            let nextDate: Date?
            switch selectedTimeRange {
            case .day:
                nextDate = calendar.date(byAdding: .hour, value: 1, to: currentDate)
            case .week, .month:
                nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate)
            case .threeMonths, .sixMonths:
                nextDate = calendar.date(byAdding: .weekOfYear, value: 1, to: currentDate)
            case .year, .all:
                nextDate = calendar.date(byAdding: .month, value: 1, to: currentDate)
            }
            
            if let next = nextDate {
                currentDate = next
            } else {
                break
            }
        }
        
        return dataPoints.sorted { $0.date < $1.date }
    }
    
    private var totalCount: Int {
        filteredEvents.count
    }
    
    private var averagePerPeriod: Double {
        guard !chartData.isEmpty else { return 0 }
        let sum = chartData.reduce(0) { $0 + $1.count }
        return Double(sum) / Double(chartData.count)
    }
    
    var body: some View {
        ZStack {
            AppBackground()
            
            ScrollView {
                VStack(spacing: 0) {
                    // Header
                    HStack {
                        Text("Trends")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                        Spacer()
                    }
                    .padding(.top, 60)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                    
                    // Main Content
                    VStack(alignment: .leading, spacing: 24) {
                        // Time Range Selector
                        TimeRangeSelector(selectedRange: $selectedTimeRange)
                        
                        // Filter Selector
                        FilterSelector(
                            filterType: $filterType,
                            selectedCategory: $selectedCategory,
                            selectedPreset: $selectedPreset,
                            categories: allCategories,
                            presets: allPresets
                        )
                        
                        if filteredEvents.isEmpty {
                            EmptyTrendsView()
                        } else {
                            // Chart
                            ChartCardView(
                                data: chartData,
                                filterType: filterType,
                                selectedCategory: selectedCategory,
                                selectedPreset: selectedPreset,
                                timeRange: selectedTimeRange
                            )
                            
                            // Stats Cards
                            StatsCardsView(
                                totalCount: totalCount,
                                averagePerPeriod: averagePerPeriod,
                                timeRange: selectedTimeRange
                            )
                        }
                    }
                    .padding(.vertical, 24)
                    .padding(.horizontal, 20)
                    .background(
                        RoundedRectangle(cornerRadius: 32)
                            .fill(Color(hex: "#1a1a2e")!.opacity(0.95))
                    )
                    
                    Spacer(minLength: 100)
                }
            }
        }
    }
}

// MARK: - Time Range Selector
struct TimeRangeSelector: View {
    @Binding var selectedRange: TrendsView.TimeRange
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(TrendsView.TimeRange.allCases, id: \.self) { range in
                    Button(action: {
                        withAnimation(.spring(response: 0.3)) {
                            selectedRange = range
                        }
                    }) {
                        Text(range.rawValue)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(selectedRange == range ? .white : .gray)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(selectedRange == range ?
                                          LinearGradient(
                                            colors: [Color(hex: "#667eea")!, Color(hex: "#764ba2")!],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                          ) :
                                          LinearGradient(
                                            colors: [Color(hex: "#2a2a4e")!],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                          )
                                    )
                            )
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }
}

// MARK: - Filter Selector
struct FilterSelector: View {
    @Binding var filterType: TrendsView.FilterType
    @Binding var selectedCategory: Category?
    @Binding var selectedPreset: EventPreset?
    let categories: [Category]
    let presets: [EventPreset]
    
    @State private var showingPresetPicker = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Filter Type Selector
            HStack(spacing: 12) {
                ForEach(TrendsView.FilterType.allCases, id: \.self) { type in
                    Button(action: {
                        withAnimation(.spring(response: 0.3)) {
                            filterType = type
                            selectedCategory = nil
                            selectedPreset = nil
                        }
                    }) {
                        Text(type.rawValue)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(filterType == type ? .white : .gray)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(filterType == type ?
                                          LinearGradient(
                                            colors: [Color(hex: "#667eea")!, Color(hex: "#764ba2")!],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                          ) :
                                          LinearGradient(
                                            colors: [Color(hex: "#2a2a4e")!],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                          )
                                    )
                            )
                    }
                }
            }
            
            // Category/Preset Picker
            if filterType == .category {
                // Categories: horizontal scrolling (usually fewer items)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        // "All" option
                        FilterChip(
                            title: "All",
                            isSelected: selectedCategory == nil,
                            color: Color(hex: "#60A5FA")!
                        ) {
                            withAnimation(.spring(response: 0.3)) {
                                selectedCategory = nil
                            }
                        }
                        
                        ForEach(categories) { category in
                            FilterChip(
                                title: category.name,
                                isSelected: selectedCategory?.id == category.id,
                                color: category.color
                            ) {
                                withAnimation(.spring(response: 0.3)) {
                                    selectedCategory = category
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
            } else {
                // Presets: button that opens searchable picker
                Button(action: {
                    showingPresetPicker = true
                }) {
                    HStack {
                        if let preset = selectedPreset {
                            HStack(spacing: 8) {
                                Image(systemName: preset.iconName)
                                    .font(.system(size: 14))
                                    .foregroundColor(preset.category?.color ?? Color(hex: "#60A5FA")!)
                                Text(preset.name)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white)
                                Spacer()
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 12))
                                    .foregroundColor(.gray)
                            }
                        } else {
                            HStack {
                                Text("All Presets")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white)
                                Spacer()
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 12))
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(hex: "#2a2a4e")!)
                    )
                }
            }
        }
        .sheet(isPresented: $showingPresetPicker) {
            PresetPickerSheet(
                presets: presets,
                selectedPreset: $selectedPreset
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
    }
}

// MARK: - Filter Chip
struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(isSelected ? .white : .gray)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ?
                          color.opacity(0.3) :
                          Color(hex: "#2a2a4e")!
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? color : Color.clear, lineWidth: 2)
            )
        }
    }
}

// MARK: - Stats Cards
struct StatsCardsView: View {
    let totalCount: Int
    let averagePerPeriod: Double
    let timeRange: TrendsView.TimeRange
    
    var body: some View {
        HStack(spacing: 12) {
            StatCard(
                title: "Total",
                value: "\(totalCount)",
                icon: "number.circle.fill",
                color: Color(hex: "#60A5FA")!
            )
            
            StatCard(
                title: "Avg/Period",
                value: String(format: "%.1f", averagePerPeriod),
                icon: "chart.line.uptrend.xyaxis",
                color: Color(hex: "#10B981")!
            )
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(color)
                Spacer()
            }
            
            Text(value)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
            
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.gray)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(hex: "#252540")!)
        )
    }
}

// MARK: - Chart Data Point
struct ChartDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let count: Int
}

// MARK: - Chart Card View
struct ChartCardView: View {
    let data: [ChartDataPoint]
    let filterType: TrendsView.FilterType
    let selectedCategory: Category?
    let selectedPreset: EventPreset?
    let timeRange: TrendsView.TimeRange
    
    private var chartTitle: String {
        if filterType == .category {
            return selectedCategory?.name ?? "All Categories"
        } else {
            return selectedPreset?.name ?? "All Presets"
        }
    }
    
    private var chartColor: Color {
        if filterType == .category {
            return selectedCategory?.color ?? Color(hex: "#60A5FA")!
        } else {
            return selectedPreset?.category?.color ?? Color(hex: "#60A5FA")!
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(chartTitle)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
            
            if data.isEmpty {
                Text("No data available for this time range")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 40)
            } else {
                Chart {
                    ForEach(data) { point in
                        LineMark(
                            x: .value("Date", point.date),
                            y: .value("Count", point.count)
                        )
                        .foregroundStyle(chartColor)
                        .interpolationMethod(.catmullRom)
                        
                        AreaMark(
                            x: .value("Date", point.date),
                            y: .value("Count", point.count)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: [chartColor.opacity(0.3), chartColor.opacity(0.05)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .interpolationMethod(.catmullRom)
                    }
                }
                .frame(height: 200)
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 5)) { value in
                        AxisGridLine()
                            .foregroundStyle(.gray.opacity(0.3))
                        AxisValueLabel {
                            if let date = value.as(Date.self) {
                                Text(formatDate(date))
                                    .font(.system(size: 10))
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine()
                            .foregroundStyle(.gray.opacity(0.3))
                        AxisValueLabel {
                            if let intValue = value.as(Int.self) {
                                Text("\(intValue)")
                                    .font(.system(size: 10))
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(hex: "#252540")!)
        )
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        switch timeRange {
        case .day:
            formatter.dateFormat = "HH:mm"
        case .week, .month:
            formatter.dateFormat = "MMM d"
        case .threeMonths, .sixMonths:
            formatter.dateFormat = "MMM d"
        case .year, .all:
            formatter.dateFormat = "MMM"
        }
        return formatter.string(from: date)
    }
}

// MARK: - Empty Trends View
struct EmptyTrendsView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            
            Text("No data available")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.gray)
            
            Text("Track some events to see trends")
                .font(.system(size: 14))
                .foregroundColor(.gray.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

// MARK: - Preset Picker Sheet
struct PresetPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let presets: [EventPreset]
    @Binding var selectedPreset: EventPreset?
    
    @State private var searchText = ""
    
    private var groupedPresets: [(category: Category?, presets: [EventPreset])] {
        let filtered = searchText.isEmpty ? presets : presets.filter { preset in
            preset.name.lowercased().contains(searchText.lowercased())
        }
        
        let grouped = Dictionary(grouping: filtered) { $0.category }
        let sorted = grouped.sorted { first, second in
            let firstName = first.key?.name ?? "Uncategorized"
            let secondName = second.key?.name ?? "Uncategorized"
            if firstName == "Uncategorized" && secondName != "Uncategorized" {
                return false
            }
            if firstName != "Uncategorized" && secondName == "Uncategorized" {
                return true
            }
            return firstName < secondName
        }
        
        return sorted.map { (category: $0.key, presets: $0.value.sorted { $0.name < $1.name }) }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "#1a1a2e")!.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Search bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                            .padding(.leading, 16)
                        
                        TextField("Search presets...", text: $searchText)
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
                            .fill(Color(hex: "#252540")!)
                    )
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 8)
                    
                    // Presets list
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            // "All Presets" option
                            Button(action: {
                                selectedPreset = nil
                                dismiss()
                            }) {
                                HStack {
                                    Image(systemName: "square.grid.2x2")
                                        .font(.system(size: 18))
                                        .foregroundColor(Color(hex: "#60A5FA")!)
                                        .frame(width: 32)
                                    
                                    Text("All Presets")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.white)
                                    
                                    Spacer()
                                    
                                    if selectedPreset == nil {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(Color(hex: "#60A5FA")!)
                                    }
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(selectedPreset == nil ?
                                              Color(hex: "#60A5FA")!.opacity(0.2) :
                                              Color(hex: "#252540")!
                                        )
                                )
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 8)
                            
                            // Grouped presets
                            ForEach(groupedPresets, id: \.category?.id) { group in
                                VStack(alignment: .leading, spacing: 12) {
                                    if let category = group.category {
                                        Text(category.name)
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(.gray)
                                            .padding(.horizontal, 20)
                                    } else {
                                        Text("Uncategorized")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(.gray)
                                            .padding(.horizontal, 20)
                                    }
                                    
                                    ForEach(group.presets) { preset in
                                        Button(action: {
                                            selectedPreset = preset
                                            dismiss()
                                        }) {
                                            HStack {
                                                Image(systemName: preset.iconName)
                                                    .font(.system(size: 18))
                                                    .foregroundColor(preset.category?.color ?? Color(hex: "#60A5FA")!)
                                                    .frame(width: 32)
                                                
                                                Text(preset.name)
                                                    .font(.system(size: 16, weight: .medium))
                                                    .foregroundColor(.white)
                                                
                                                Spacer()
                                                
                                                if selectedPreset?.id == preset.id {
                                                    Image(systemName: "checkmark")
                                                        .font(.system(size: 14, weight: .semibold))
                                                        .foregroundColor(preset.category?.color ?? Color(hex: "#60A5FA")!)
                                                }
                                            }
                                            .padding(.horizontal, 20)
                                            .padding(.vertical, 12)
                                            .background(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .fill(selectedPreset?.id == preset.id ?
                                                          (preset.category?.color ?? Color(hex: "#60A5FA")!).opacity(0.2) :
                                                          Color(hex: "#252540")!
                                                    )
                                            )
                                        }
                                        .padding(.horizontal, 20)
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
            .navigationTitle("Select Preset")
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

#Preview {
    TrendsView()
        .modelContainer(for: [TrackedEvent.self, EventPreset.self, Category.self])
}
