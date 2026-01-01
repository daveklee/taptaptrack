# iOS Shortcuts Setup Guide

TapTapTrack supports iOS Shortcuts, allowing you to quickly track events from your home screen or Siri without opening the app first. The app will open automatically to show the confirmation screen where you can verify location, add notes, or make other updates.

## How It Works

When you run a Shortcut that tracks an event:
1. The event is created immediately
2. The app opens automatically
3. The confirmation screen appears (just like when using the widget)
4. You can verify location, add notes, or make any updates before confirming

## Setting Up a Shortcut

### Method 1: Using the Shortcuts App

1. **Open the Shortcuts app** on your iPhone
2. **Tap the "+" button** to create a new shortcut
3. **Search for "Track Event"** in the actions list
4. **Add the "Track Event" action** to your shortcut
5. **Select an Event Preset** from the dropdown
6. **Name your shortcut** (e.g., "Track Coffee Break")
7. **Tap "Done"**

### Method 2: Adding to Home Screen

1. **Create a shortcut** using Method 1 above
2. **Tap the shortcut** in the Shortcuts app
3. **Tap the "..." button** (three dots) in the top right
4. **Tap "Add to Home Screen"**
5. **Customize the icon and name** if desired
6. **Tap "Add"**

Now you'll have a home screen button that tracks your event and opens the app for confirmation!

### Method 3: Using Siri

1. **Create a shortcut** using Method 1 above
2. **Tap the shortcut** in the Shortcuts app
3. **Tap "Add to Siri"**
4. **Record a phrase** (e.g., "Track my coffee break")
5. **Tap "Done"**

Now you can say "Hey Siri, [your phrase]" to track events!

## Tips

- **Create multiple shortcuts** for different events you track frequently
- **Use descriptive names** for your shortcuts to make them easy to find
- **Add to Control Center** for even faster access (Settings → Control Center → Shortcuts)
- **Use Siri Shortcuts** for hands-free tracking while driving or exercising

## Troubleshooting

### "Internal error occurred" or "Connection invalidated" when running shortcut
- **Check Console Logs**: App Intents run in a separate process, so logs might not appear in Xcode's main console. Try:
  - In Xcode: Window → Devices and Simulators → Select your device → Open Console
  - Filter for "TrackEventIntent" or "EventPresetQuery" to see the logs
  - Or use Console.app on your Mac to view device logs
- **Make sure the app has been opened at least once** after installation - this initializes the SwiftData store
- **Delete and recreate the shortcut** - sometimes shortcuts get out of sync with the app
- **Restart your device** - this can help sync App Intents with Shortcuts
- **Clean and rebuild**: Product → Clean Build Folder, then rebuild
- Make sure you're running iOS 17.0 or later
- Check that the App Group is properly configured in both the app and widget extension targets
- In Xcode, make sure `TrackEventIntent.swift` is included in the main app target (TapTapTrack), not just the widget extension
- **If the error persists**: The App Intent might be crashing when accessing SwiftData. Try:
  1. Open the app first and create at least one event preset
  2. Then try creating the shortcut again
  3. Check Xcode console for specific error messages

### Shortcut doesn't appear in Shortcuts app
- Make sure you're running iOS 17.0 or later
- Try restarting your device
- **Make sure the app has been opened at least once** after installation
- The "Track Event" action should appear when you search in Shortcuts

### App doesn't open when running shortcut
- Check that "Open App" is enabled in the shortcut settings
- Make sure the app isn't restricted in Screen Time settings
- The shortcut should automatically open the app when run

### Confirmation screen doesn't appear
- The app should open automatically when the shortcut runs
- If it doesn't, try opening the app manually after running the shortcut
- The event will still be created, you can find it in the History tab
- Make sure the app has been opened at least once to initialize the data store

## Technical Details

The shortcut uses App Intents to communicate with TapTapTrack. When you run a shortcut:
1. The `TrackEventIntent` stores the selected preset ID in shared UserDefaults
2. The app opens (if not already open)
3. The app detects the pending preset ID and creates the event
4. The confirmation screen appears automatically

This is the same mechanism used by the widget, ensuring consistent behavior across all entry points.

