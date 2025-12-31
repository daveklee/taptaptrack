//
//  TapTapTrackWidget.swift
//  TapTapTrackWidget
//
//  Widget for quick event tracking

import WidgetKit
import SwiftUI
import SwiftData

@main
struct TapTapTrackWidget: Widget {
    let kind: String = "TapTapTrackWidget"
    
    @available(iOS 17.0, *)
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: QuickTrackWidgetConfiguration.self, provider: EventPresetProvider()) { entry in
            TapTapTrackWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    if let darkColor = Color(hex: "#1a1a2e") {
                        darkColor.opacity(0.75)
                    } else {
                        Color.black.opacity(0.75)
                    }
                }
        }
        .configurationDisplayName("Quick Track")
        .description("Quickly track events without opening the app")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

@available(iOS 17.0, *)
struct EventPresetProvider: AppIntentTimelineProvider {
    typealias Intent = QuickTrackWidgetConfiguration
    
    func placeholder(in context: Context) -> EventPresetEntry {
        EventPresetEntry(
            date: Date(),
            presets: [
                PresetInfo(id: UUID(), name: "Coffee", iconName: "cup.and.saucer.fill", colorHex: "#667eea", categoryName: "Personal"),
                PresetInfo(id: UUID(), name: "Exercise", iconName: "figure.strengthtraining.traditional", colorHex: "#EC4899", categoryName: "Health"),
                PresetInfo(id: UUID(), name: "Work", iconName: "briefcase.fill", colorHex: "#6366F1", categoryName: "Work"),
                PresetInfo(id: UUID(), name: "Sleep", iconName: "bed.double.fill", colorHex: "#EC4899", categoryName: "Health")
            ]
        )
    }
    
    func snapshot(for configuration: QuickTrackWidgetConfiguration, in context: Context) async -> EventPresetEntry {
        await loadPresets(configuration: configuration)
    }
    
    func timeline(for configuration: QuickTrackWidgetConfiguration, in context: Context) async -> Timeline<EventPresetEntry> {
        let entry = await loadPresets(configuration: configuration)
        return Timeline(entries: [entry], policy: .atEnd)
    }
    
    @MainActor
    private func loadPresets(configuration: QuickTrackWidgetConfiguration) async -> EventPresetEntry {
        do {
            let schema = Schema([
                Category.self,
                EventPreset.self,
            ])
            let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            let context = container.mainContext
            
            let descriptor = FetchDescriptor<EventPreset>(
                sortBy: [SortDescriptor(\.category?.order), SortDescriptor(\.createdAt)]
            )
            
            let allPresets = try context.fetch(descriptor)
            
            // If configuration has selected presets, use those in the order specified; otherwise use all
            guard let selectedPresets = configuration.selectedPresets, !selectedPresets.isEmpty else {
                // No selection - use all presets in default order
                let presetInfos = Array(allPresets.prefix(8)).map { preset in
                    PresetInfo(
                        id: preset.id,
                        name: preset.name,
                        iconName: preset.iconName,
                        colorHex: preset.colorHex,
                        categoryName: preset.category?.name ?? "Uncategorized"
                    )
                }
                return EventPresetEntry(date: Date(), presets: presetInfos)
            }
            
            // Create a dictionary for quick lookup
            let presetDict = Dictionary(uniqueKeysWithValues: allPresets.map { ($0.id, $0) })
            
            // Preserve the order from the configuration
            let presetsToUse = selectedPresets.compactMap { entity -> EventPreset? in
                presetDict[entity.id]
            }
            
            let presetInfos = presetsToUse.map { preset in
                PresetInfo(
                    id: preset.id,
                    name: preset.name,
                    iconName: preset.iconName,
                    colorHex: preset.colorHex,
                    categoryName: preset.category?.name ?? "Uncategorized"
                )
            }
            
            return EventPresetEntry(date: Date(), presets: presetInfos)
        } catch {
            // Return placeholder on error
            return EventPresetEntry(date: Date(), presets: [])
        }
    }
}

// Fallback provider for iOS 16
struct EventPresetProviderLegacy: TimelineProvider {
    func placeholder(in context: Context) -> EventPresetEntry {
        EventPresetEntry(
            date: Date(),
            presets: [
                PresetInfo(id: UUID(), name: "Coffee", iconName: "cup.and.saucer.fill", colorHex: "#667eea", categoryName: "Personal"),
                PresetInfo(id: UUID(), name: "Exercise", iconName: "figure.strengthtraining.traditional", colorHex: "#EC4899", categoryName: "Health"),
                PresetInfo(id: UUID(), name: "Work", iconName: "briefcase.fill", colorHex: "#6366F1", categoryName: "Work"),
                PresetInfo(id: UUID(), name: "Sleep", iconName: "bed.double.fill", colorHex: "#EC4899", categoryName: "Health")
            ]
        )
    }
    
    func getSnapshot(in context: Context, completion: @escaping (EventPresetEntry) -> Void) {
        Task { @MainActor in
            let entry = await loadPresets()
            completion(entry)
        }
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        Task { @MainActor in
            let entry = await loadPresets()
            let timeline = Timeline(entries: [entry], policy: .atEnd)
            completion(timeline)
        }
    }
    
    @MainActor
    private func loadPresets() async -> EventPresetEntry {
        do {
            let schema = Schema([
                Category.self,
                EventPreset.self,
            ])
            let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            let context = container.mainContext
            
            let descriptor = FetchDescriptor<EventPreset>(
                sortBy: [SortDescriptor(\.category?.order), SortDescriptor(\.createdAt)]
            )
            
            let presets = try context.fetch(descriptor)
            
            let presetInfos = presets.prefix(8).map { preset in
                PresetInfo(
                    id: preset.id,
                    name: preset.name,
                    iconName: preset.iconName,
                    colorHex: preset.colorHex,
                    categoryName: preset.category?.name ?? "Uncategorized"
                )
            }
            
            return EventPresetEntry(date: Date(), presets: Array(presetInfos))
        } catch {
            return EventPresetEntry(date: Date(), presets: [])
        }
    }
}

struct EventPresetEntry: TimelineEntry {
    let date: Date
    let presets: [PresetInfo]
}

struct PresetInfo: Identifiable {
    let id: UUID
    let name: String
    let iconName: String
    let colorHex: String?
    let categoryName: String
    
    var color: Color {
        if let colorHex = colorHex, !colorHex.isEmpty, let color = Color(hex: colorHex) {
            return color
        }
        return Color(hex: "#667eea") ?? .purple
    }
}

struct TapTapTrackWidgetEntryView: View {
    var entry: EventPresetEntry
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(presets: entry.presets.prefix(4))
        case .systemMedium:
            MediumWidgetView(presets: entry.presets.prefix(6))
        case .systemLarge:
            LargeWidgetView(presets: entry.presets.prefix(8))
        default:
            SmallWidgetView(presets: entry.presets.prefix(4))
        }
    }
}

// MARK: - Small Widget View
struct SmallWidgetView: View {
    let presets: ArraySlice<PresetInfo>
    
    var body: some View {
        GeometryReader { geometry in
            if presets.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 28))
                        .foregroundStyle(.secondary)
                    Text("No events")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Small widget: 2x2 grid (4 presets max)
                let gridPresets = Array(presets.prefix(4))
                let spacing: CGFloat = 4
                let padding: CGFloat = 4
                let availableWidth = geometry.size.width - (padding * 2)
                let availableHeight = geometry.size.height - (padding * 2)
                let cardWidth = max(0, floor((availableWidth - spacing) / 2))
                let cardHeight = max(0, floor((availableHeight - spacing) / 2))
                
                LazyVGrid(
                    columns: [
                        GridItem(.fixed(cardWidth), spacing: spacing),
                        GridItem(.fixed(cardWidth), spacing: spacing)
                    ],
                    alignment: .center,
                    spacing: spacing
                ) {
                    ForEach(gridPresets) { preset in
                        Link(destination: URL(string: "taptaptrack://track/\(preset.id.uuidString)")!) {
                            PresetCardView(preset: preset, size: .small)
                                .frame(width: cardWidth, height: cardHeight)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(padding)
            }
        }
    }
}

// MARK: - Medium Widget View
struct MediumWidgetView: View {
    let presets: ArraySlice<PresetInfo>
    
    var body: some View {
        GeometryReader { geometry in
            if presets.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 36))
                        .foregroundStyle(.secondary)
                    Text("No events configured")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Medium widget: 3x2 grid (6 presets max)
                let gridPresets = Array(presets.prefix(6))
                let spacing: CGFloat = 4
                let padding: CGFloat = 4
                let availableWidth = geometry.size.width - (padding * 2)
                let availableHeight = geometry.size.height - (padding * 2)
                let cardWidth = max(0, floor((availableWidth - (spacing * 2)) / 3))
                let cardHeight = max(0, floor((availableHeight - spacing) / 2))
                
                LazyVGrid(
                    columns: [
                        GridItem(.fixed(cardWidth), spacing: spacing),
                        GridItem(.fixed(cardWidth), spacing: spacing),
                        GridItem(.fixed(cardWidth), spacing: spacing)
                    ],
                    alignment: .center,
                    spacing: spacing
                ) {
                    ForEach(gridPresets) { preset in
                        Link(destination: URL(string: "taptaptrack://track/\(preset.id.uuidString)")!) {
                            PresetCardView(preset: preset, size: .medium)
                                .frame(width: cardWidth, height: cardHeight)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(padding)
            }
        }
    }
}

// MARK: - Large Widget View
struct LargeWidgetView: View {
    let presets: ArraySlice<PresetInfo>
    
    var body: some View {
        GeometryReader { geometry in
            if presets.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 44))
                        .foregroundStyle(.secondary)
                    Text("No events configured")
                        .font(.body)
                        .foregroundStyle(.secondary)
                    Text("Add events in the app")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Large widget: 4x2 grid (8 presets max)
                let gridPresets = Array(presets.prefix(8))
                let spacing: CGFloat = 6
                let padding: CGFloat = 6
                let availableWidth = geometry.size.width - (padding * 2)
                let availableHeight = geometry.size.height - (padding * 2)
                let cardWidth = max(0, floor((availableWidth - (spacing * 3)) / 4))
                let cardHeight = max(0, floor((availableHeight - spacing) / 2))
                
                LazyVGrid(
                    columns: [
                        GridItem(.fixed(cardWidth), spacing: spacing),
                        GridItem(.fixed(cardWidth), spacing: spacing),
                        GridItem(.fixed(cardWidth), spacing: spacing),
                        GridItem(.fixed(cardWidth), spacing: spacing)
                    ],
                    alignment: .center,
                    spacing: spacing
                ) {
                    ForEach(gridPresets) { preset in
                        Link(destination: URL(string: "taptaptrack://track/\(preset.id.uuidString)")!) {
                            PresetCardView(preset: preset, size: .large)
                                .frame(width: cardWidth, height: cardHeight)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(padding)
            }
        }
    }
}

// MARK: - Preset Card View (matches app design)
enum PresetCardSize {
    case small, medium, large
    
    var iconSize: CGFloat {
        switch self {
        case .small: return 24
        case .medium: return 28
        case .large: return 32
        }
    }
    
    var fontSize: Font {
        switch self {
        case .small: return .caption2
        case .medium: return .caption
        case .large: return .subheadline
        }
    }
    
    var cardHeight: CGFloat? {
        switch self {
        case .small: return nil // Let it fill available space
        case .medium: return nil
        case .large: return nil
        }
    }
    
    var padding: CGFloat {
        switch self {
        case .small: return 8
        case .medium: return 10
        case .large: return 12
        }
    }
}

struct PresetCardView: View {
    let preset: PresetInfo
    let size: PresetCardSize
    
    init(preset: PresetInfo, size: PresetCardSize = .medium) {
        self.preset = preset
        self.size = size
    }
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Card background with gradient (matching app design)
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
            VStack(spacing: 3) {
                Image(systemName: preset.iconName)
                    .font(.system(size: size.iconSize, weight: .medium))
                    .foregroundColor(.white)
                
                Text(preset.name)
                    .font(size.fontSize)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(size.padding)
            .padding(.top, 2)
            
            // Plus button indicator (matching app design)
            Circle()
                .fill(Color.black.opacity(0.3))
                .frame(width: 18, height: 18)
                .overlay(
                    Image(systemName: "plus")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                )
                .padding(5)
        }
        .clipped()
        .contentShape(Rectangle())
    }
}

// Note: Color(hex:) extension is defined in Category.swift and shared with the widget extension

#Preview(as: .systemSmall) {
    TapTapTrackWidget()
} timeline: {
    EventPresetEntry(
        date: Date(),
        presets: [
            PresetInfo(id: UUID(), name: "Coffee", iconName: "cup.and.saucer.fill", colorHex: "#667eea", categoryName: "Personal"),
            PresetInfo(id: UUID(), name: "Exercise", iconName: "figure.strengthtraining.traditional", colorHex: "#EC4899", categoryName: "Health"),
            PresetInfo(id: UUID(), name: "Work", iconName: "briefcase.fill", colorHex: "#6366F1", categoryName: "Work"),
            PresetInfo(id: UUID(), name: "Sleep", iconName: "bed.double.fill", colorHex: "#EC4899", categoryName: "Health")
        ]
    )
}
