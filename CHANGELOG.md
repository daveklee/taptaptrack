# Changelog

All notable changes to Tap Tap Track will be documented in this file.

## [1.1] - 2025-01-XX

### Added
- **Custom colors for event presets**: You can now pick a custom color for each event preset
  - Color picker with 16 curated color options in the preset creation/editing screens
  - Colors are applied to:
    - Tap boxes on the main tracking screen
    - Event icons in the history view
    - Event icons in the trends view
    - Preset cards in the manage view
  - Existing presets without colors will use the default purple color

### Changed
- Improved visual consistency with color-coded events throughout the app
- Enhanced preset management with color customization

### Technical
- Added `colorHex` property to `EventPreset` and `TrackedEvent` models
- Implemented graceful migration for existing data without color values
- Updated UI components to use preset colors instead of hardcoded values

## [1.0] - Initial Release

### Features
- One-tap event tracking
- Custom categories and event presets
- 200+ icon options organized by category
- Event history with date grouping
- CSV export functionality
- Trends view with charts and statistics
- Dark theme with modern UI design
- SwiftData persistence
- Haptic feedback
