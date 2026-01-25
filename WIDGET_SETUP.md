# Widget Extension Setup Guide

_Last updated for version 1.5.1_

This guide will help you add the widget extension to your Xcode project.

## Steps to Add Widget Extension

1. **Open Xcode Project**
   - Open `TapTapTrack.xcodeproj` in Xcode

2. **Add Widget Extension Target**
   - In Xcode, go to File → New → Target
   - Select "Widget Extension" under iOS
   - Name it "TapTapTrackWidget"
   - Make sure "Include Configuration Intent" is checked (for iOS 17+ App Intents)
   - Click Finish

3. **Replace Generated Files**
   - Delete the auto-generated widget files in the new target
   - Add the files from `TapTapTrackWidget/` folder:
     - `TapTapTrackWidget.swift`
     - `TrackEventIntent.swift`

4. **Configure App Groups**
   - Select the main app target → Signing & Capabilities
   - Click "+ Capability" → Add "App Groups"
   - Add group: `group.com.taptaptrack`
   - Repeat for the widget extension target

5. **Configure Info.plist for Deep Linking**
   - In the main app target, add URL Scheme:
     - Open `Info.plist` (or add to target's Info tab)
     - Add URL Types:
       - Identifier: `com.taptaptrack`
       - URL Schemes: `taptaptrack`

6. **Link SwiftData Models**
   - Make sure the widget extension target has access to:
     - `Category.swift` (IMPORTANT: This contains the Color(hex:) extension)
     - `EventPreset.swift`
     - `TrackedEvent.swift`
   - Add these files to the widget extension target's "Compile Sources"
   - In Xcode: Select each file → Show File Inspector → Check the widget extension target in "Target Membership"
   - **Note**: If you see "Ambiguous use of 'init(hex:)'" errors, ensure Category.swift is included in the widget extension target and remove any duplicate Color extensions

7. **Set Deployment Target**
   - Ensure both targets have the same iOS deployment target (iOS 17.0+ recommended for App Intents)

8. **Build and Run**
   - Build the widget extension target
   - Run the app on a device or simulator
   - Add the widget to your home screen

## Features

The widget allows users to:
- Track events directly from the home screen
- See up to 8 event presets (depending on widget size)
- Automatically opens the app to show confirmation screen
- Edit location, add number, and add notes after tracking

## Widget Sizes

- **Small**: Shows 4 event presets in a 2x2 grid
- **Medium**: Shows 6 event presets in a 3x2 grid
- **Large**: Shows 8 event presets in a 4x2 grid

## Notes

- The widget uses App Intents (iOS 17+) for interactive buttons
- For iOS 16, it falls back to deep linking
- Events are created immediately when tapped from the widget
- The app opens automatically to show the confirmation screen where users can:
  - Confirm the tap was registered
  - Correct the location
  - Add a number value
  - Add a note

