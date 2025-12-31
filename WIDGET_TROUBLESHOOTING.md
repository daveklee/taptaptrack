# Widget Troubleshooting Guide

If widget buttons aren't working, follow these steps:

## 1. Verify URL Scheme Configuration

The widget uses deep linking (`taptaptrack://track/{presetID}`). Ensure:

- **Main App Target** → Info tab → URL Types
  - Add URL Type if missing:
    - Identifier: `com.taptaptrack`
    - URL Schemes: `taptaptrack`
    - Role: `Editor`

## 2. Verify App Groups

Both targets must have the same App Group:

- **Main App Target** → Signing & Capabilities → App Groups
  - Add: `group.com.taptaptrack`
  
- **Widget Extension Target** → Signing & Capabilities → App Groups
  - Add: `group.com.taptaptrack`

## 3. Test Deep Linking Directly

Test if deep linking works by running this in Terminal (with simulator running):

```bash
xcrun simctl openurl booted "taptaptrack://track/00000000-0000-0000-0000-000000000000"
```

Replace the UUID with an actual preset ID from your app. The app should open and switch to the Track tab.

## 4. Check Console Logs

When tapping a widget button, check Xcode console for:
- URL handling messages
- Any errors from `handleDeepLink`
- UserDefaults access errors

## 5. Verify Widget is Using Links

The widget now uses `Link` instead of App Intents for better reliability. Check that:
- All widget buttons use `Link(destination:)` 
- No `Button(intent:)` calls remain

## 6. Clean Build

1. Product → Clean Build Folder (Shift+Cmd+K)
2. Delete Derived Data
3. Rebuild both targets
4. Reinstall app and widget

## 7. Verify Widget Extension is Running

- Check that the widget extension scheme is selected
- Build and run the widget extension target
- Add widget to home screen
- Tap a button and verify app opens

## 8. Check UserDefaults

Add debug logging to verify UserDefaults is working:

```swift
// In handleDeepLink or TrackView
print("Storing preset ID: \(presetID.uuidString)")
print("UserDefaults value: \(UserDefaults(suiteName: "group.com.taptaptrack")?.string(forKey: "pendingPresetID") ?? "nil")")
```

## Common Issues

- **"Connection invalidated"**: App Intent crashed - fixed by using Link instead
- **Nothing happens on tap**: URL scheme not configured or deep link handler not working
- **App opens but no event created**: UserDefaults not shared or TrackView not checking for pending preset ID

