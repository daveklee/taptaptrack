# App Store Distribution Preparation

This document outlines the changes made and remaining steps needed to prepare Tap Tap Track for App Store distribution, particularly with the new location capabilities.

## ✅ Changes Already Made

### 1. Release Build Configuration
- **Code Signing Identity**: Changed from "Apple Development" to "Apple Distribution" for Release builds
- **Swift Optimization**: Added `SWIFT_OPTIMIZATION_LEVEL = "-O"` for Release builds (optimized)
- **Previews Disabled**: Set `ENABLE_PREVIEWS = NO` for Release builds

### 2. Privacy Manifest (PrivacyInfo.xcprivacy)
- Created `PrivacyInfo.xcprivacy` file (required for iOS 17+ apps)
- Declared location data collection for app functionality
- Declared required API usage reasons (UserDefaults, File Timestamps, System Boot Time, Disk Space, Active Keyboards)
- Added to Xcode project and Resources build phase

### 3. Location Permissions
- ✅ `NSLocationWhenInUseUsageDescription` is already configured in both Debug and Release builds
- Permission string: "Tap Tap Track needs your location to track events with location data and identify nearby businesses."

## 📋 Remaining Manual Steps in Xcode

### 1. Verify Privacy Manifest in Xcode
1. Open the project in Xcode
2. Verify that `PrivacyInfo.xcprivacy` appears in the project navigator under the TapTapTrack folder
3. If it doesn't appear, right-click the TapTapTrack folder → "Add Files to TapTapTrack" → Select `PrivacyInfo.xcprivacy` → Ensure "Copy items if needed" is checked and "Add to targets: TapTapTrack" is selected

### 2. App Store Connect Configuration
1. **App Store Connect Setup**:
   - Log in to [App Store Connect](https://appstoreconnect.apple.com)
   - Create or select your app
   - Ensure bundle identifier matches: `com.taptaptrack.app`
   - Set up app metadata, screenshots, description, etc.

2. **Privacy Questions** (Required for apps with location):
   - When submitting, you'll be asked about data collection
   - Answer: **Yes, we collect location data**
   - Purpose: **App Functionality** (to track events with location)
   - Linked to User: **No** (location is not linked to user identity)
   - Used for Tracking: **No** (we don't track users across apps/websites)

3. **Export Compliance**:
   - If asked about encryption, answer based on your usage
   - Since you're using standard iOS APIs (CoreLocation, MapKit), you likely qualify for exemption
   - Answer: "Yes, my app uses encryption" → "No, my app uses encryption that is exempt from export compliance documentation"

### 3. Build and Archive
1. In Xcode, select **Product → Destination → Any iOS Device** (or a connected device)
2. Select **Product → Scheme → TapTapTrack**
3. Select **Product → Archive**
4. Wait for the archive to complete
5. In the Organizer window:
   - Click **Distribute App**
   - Select **App Store Connect**
   - Follow the distribution wizard
   - Select **Upload** (not Export)

### 4. Version and Build Numbers
- **Marketing Version**: 1.2 (already set)
- **Current Project Version**: 1 (you may want to increment this for each build)
- Consider using build numbers that increment automatically (e.g., use `$(CURRENT_PROJECT_VERSION)` or set up CI/CD)

### 5. Capabilities Check
Verify in Xcode → Signing & Capabilities:
- ✅ Location Services capability should be automatically added when you use CoreLocation
- No additional capabilities needed for "When In Use" location

### 6. TestFlight (Optional but Recommended)
1. After uploading to App Store Connect, you can distribute via TestFlight
2. Add internal or external testers
3. Test the location functionality thoroughly before public release

## 🔍 Verification Checklist

Before submitting to App Store:

- [ ] Privacy Manifest file is included in the project
- [ ] Location permission string is clear and accurate
- [ ] App builds successfully in Release configuration
- [ ] Archive builds without errors
- [ ] App Store Connect app record is created
- [ ] Privacy questions are answered correctly
- [ ] TestFlight testing completed (if using)
- [ ] Location functionality tested on real devices
- [ ] App works correctly when location permission is denied
- [ ] App works correctly when location services are disabled

## 📝 Notes

### Location Data Collection
- The app collects location data (GPS coordinates) only when:
  - User enables location tracking for a category
  - User tracks an event in that category
- Location data is:
  - Stored locally on device only
  - Not transmitted to any servers (except Apple's MapKit for business name lookup)
  - Not linked to user identity
  - Not used for tracking across apps/websites

### Privacy Manifest API Reasons
The Privacy Manifest declares usage of these APIs with required reasons:
- **UserDefaults** (CA92.1): Accessing app-specific preferences
- **File Timestamps** (C617.1): Accessing file modification dates
- **System Boot Time** (35F9.1): Measuring time intervals
- **Disk Space** (E174.1): Checking available storage
- **Active Keyboards** (54BD.1): Detecting active keyboard

These are standard system APIs that SwiftData and SwiftUI use internally.

## 🚨 Important Reminders

1. **Test on Real Devices**: Location services behave differently on simulators vs. real devices
2. **Permission Handling**: Ensure your app gracefully handles:
   - Permission denied
   - Location services disabled
   - No internet connection (for business name lookup)
3. **Privacy Policy**: Make sure your privacy policy (if you have one) accurately describes location data usage
4. **App Review**: Apple may test location functionality, so ensure it works as described

## 📚 Additional Resources

- [App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Privacy Manifest Documentation](https://developer.apple.com/documentation/bundleresources/privacy_manifest_files)
- [Location Services Best Practices](https://developer.apple.com/documentation/corelocation)

