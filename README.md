# Tap Tap Track

A beautifully designed iOS app for tracking life events with just one tap.

🌐 **Website**: [taptaptrack.com](https://taptaptrack.com)

![iOS 17.0+](https://img.shields.io/badge/iOS-17.0+-blue.svg)
![SwiftUI](https://img.shields.io/badge/SwiftUI-5.0-orange.svg)
![SwiftData](https://img.shields.io/badge/SwiftData-Persistence-green.svg)

## Features

### 📱 Track Screen
- **One-tap tracking** - Instantly log events with the current timestamp
- **Long press for notes** - Add optional context to any event
- **Category organization** - Events grouped by your custom categories
- **Haptic feedback** - Satisfying tactile confirmation

### 📊 History Screen
- **Daily stats** - See events tracked today and this week
- **Grouped by date** - Events organized with clear date headers
- **Full details** - View event names, categories, times, and notes
- **CSV Export** - Export all your data with one tap

### ⚙️ Manage Screen
- **Custom categories** - Create Work, Personal, Health, Social, or any category
- **Event presets** - Set up frequently-tracked events with custom names and icons
- **200+ icon options** - Choose from 12 categories including health, food, work, social, travel, and more
- **Easy editing** - Update or delete categories and presets anytime
- **Smart deletion** - When deleting presets, choose to keep or remove associated tracked events

## Design

Tap Tap Track features a modern dark theme with:
- Purple/blue gradient backgrounds
- Smooth animations and transitions
- Rounded cards and buttons
- Custom tab bar navigation
- iOS design language

## Requirements

- iOS 17.0 or later
- Xcode 15.0 or later

## Installation

1. Clone this repository
2. Open `TapTapTrack.xcodeproj` in Xcode
3. Select your target device or simulator
4. Build and run (⌘R)

## Project Structure

```
TapTapTrack/
├── TapTrackApp.swift          # App entry point & data seeding
├── Models/
│   ├── Category.swift         # Category data model
│   ├── EventPreset.swift      # Event preset model
│   └── TrackedEvent.swift     # Tracked event model
├── Views/
│   ├── ContentView.swift      # Main tab navigation
│   ├── TrackView.swift        # Event tracking screen
│   ├── HistoryView.swift      # Event history screen
│   ├── ManageView.swift       # Settings/management screen
│   └── Components/
│       ├── AppBackground.swift # Shared gradient backgrounds
│       └── EditEventSheet.swift # Event editing sheet
└── Assets.xcassets/           # App icons and colors
```

## Data Persistence

Tap Tap Track uses SwiftData for local persistence. All your events, categories, and presets are stored on-device and persist between app launches.

### Seeded Data

On first launch, the app creates starter data:
- **Categories**: Work, Personal, Health, Social
- **Presets**: City, Exercise, Coffee Break, Event, Sleep

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

Feel free to use this code for your own projects!

