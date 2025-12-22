# Changelog

All notable changes to Tap Tap Track will be documented in this file.

## [1.3] - 2025-12-XX

### Added
- **Foursquare (Swarm) Checkin Import**: Import your Foursquare checkin history into Tap Tap Track
  - Request your data from the Swarm app through privacy settings
  - Import checkins from Foursquare JSON export files
  - Automatically creates an "Imported" category for imported checkins
  - Preserves all location data (venue names, coordinates, addresses)
  - Maintains original timestamps with proper timezone conversion
  - Automatic de-duplication prevents importing events that already exist
  - Step-by-step help guide available in-app and on website
  - Import button located in Manage settings page under "Import Data" section
- **Enhanced Event History Search**: Powerful search and filtering capabilities for large event datasets
  - Keyword search across all events (event names, categories, and notes)
  - Date range filtering with start and end date pickers
  - Quick date filter buttons (Today, This Week, This Month, This Year)
  - Combined keyword and date range filtering for precise results
  - Debounced search for smooth performance while typing
  - Clear all filters button for easy reset
- **Tap to View Event Details**: Tap any event in the history view to open full event details
  - Quick access to event information without using edit button
  - Opens the same detailed edit view with all event information
- **Delete Confirmation Dialog**: Safety confirmation when deleting events
  - "Are you sure?" dialog prevents accidental deletions
  - Shows event name in confirmation message
  - Clear cancel and delete options

### Changed
- Enhanced trends charts to use bar charts with appropriate aggregation periods
  - 1D: Hourly bars
  - 1W, 1M: Daily bars
  - 3M, 6M: Weekly bars
  - 1Y, All: Monthly bars
- Improved location display in edit/view screens
  - Prominently featured location name and address
  - Embedded map view showing checkin location
  - "Open in Maps" button for quick navigation
- Updated import section UI with help button for Foursquare import
- Improved "Add Note" button icon for better visual clarity
- **Performance Optimizations for Large Datasets**:
  - Lazy loading of event cards (only renders visible items)
  - Cached date formatters for improved efficiency
  - Lazy evaluation for stats calculations and filtering
  - Optimized search performance with debouncing
  - Better memory management when handling thousands of events

## [1.2.2] - 2025-12-XX

### Added
- **CSV Import functionality**: Import events from previously exported CSV files
  - Import Tap Tap Track data from CSV files exported from other devices
  - Automatic de-duplication prevents importing events that already exist
  - Automatically creates categories and presets as needed during import
  - Import button located in Manage settings page
  - Clear labeling distinguishes Tap Tap Track imports from future import options

### Changed
- Moved import functionality from History view to Manage settings page
- Improved import user experience with progress indicators and detailed success/error messages

## [1.2.1] - 2025-12-18

### Changed
- Updated app icon with larger, solid white logo design

## [1.2] - 2025-01-XX

### Added
- **Location logging for events**: Log events with location data and nearby business information
  - **Category-based location logging**: Enable location logging per category when creating or editing categories
  - **Automatic location capture**: When tracking events in location-enabled categories, the app automatically captures:
    - GPS coordinates (latitude and longitude)
    - Nearby business names using Apple's MapKit
    - Full address information
  - **Business name detection**: Automatically identifies and suggests nearby businesses, restaurants, and points of interest
  - **Location editing**: 
    - Edit location names directly in the confirmation screen
    - Select from a list of nearby businesses
    - Enter custom location names
    - Edit coordinates manually in the edit screen
  - **Prominent location display**: Location names are prominently featured in the history view for easy identification
  - **Flexible location data**: 
    - Location name is optional - you can still check-in with a single tap
    - Coordinates can be captured even without internet connection
    - Business names require internet connectivity for MapKit searches

### Changed
- Enhanced event confirmation screen to display location information when available
- Improved edit screen with location data editing capabilities
- Updated history view to prominently display location names for events with location data
- Category management now includes location logging toggle

### Technical
- Added `locationTrackingEnabled` property to `Category` model
- Added location fields (`latitude`, `longitude`, `locationName`, `address`) to `TrackedEvent` model
- Implemented `LocationManager` service using CoreLocation and MapKit
- Added location permission handling (`NSLocationWhenInUseUsageDescription`)
- Integrated MapKit's `MKLocalSearch` for business discovery
- Implemented reverse geocoding for address information

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
