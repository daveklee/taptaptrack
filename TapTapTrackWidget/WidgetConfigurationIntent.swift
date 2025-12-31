//
//  WidgetConfigurationIntent.swift
//  TapTapTrackWidget
//
//  Configuration intent for selecting which presets appear in the widget

import WidgetKit
import AppIntents

@available(iOS 17.0, *)
struct QuickTrackWidgetConfiguration: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Configure Quick Track Widget"
    static var description = IntentDescription("Choose which event presets appear in your widget and their order")
    
    @Parameter(
        title: "Selected Presets",
        description: "Choose up to 8 event presets to display. Drag to reorder."
    )
    var selectedPresets: [EventPresetEntity]?
    
    static var parameterSummary: some ParameterSummary {
        Summary("Show \(\.$selectedPresets)")
    }
}

