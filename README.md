# SMB Photo Sync for iOS

A native iOS app that syncs photos from your iPhone to an SMB (Samba/Windows) network drive with automatic background sync and Shortcuts integration.

## Features

- **One-Click Sync**: Instantly upload photos to your network drive
- **Smart Upload**: Automatically skips photos that already exist on the server
- **Background Sync**: Set automatic sync intervals (1-12 hours)
- **Shortcuts Integration**: Automate syncing with iOS Shortcuts
- **Parallel Uploads**: Upload up to 10 photos simultaneously for faster sync
- **Secure**: Credentials stored safely in iOS Keychain
- **Offline-First**: No cloud services, direct iPhone to SMB connection

## Requirements

- iOS 16.0 or later
- Xcode 15.0 or later (for building)
- iPhone with access to SMB server

## Building the App

### 1. Open in Xcode
```bash
cd SMBPhotoSync
open SMBPhotoSync.xcodeproj
```

### 2. Configure Signing
1. Select the project in Xcode navigator
2. Go to "Signing & Capabilities" tab
3. Select your Apple ID team
4. Xcode will automatically manage signing

### 3. Build and Run
1. Connect your iPhone via USB
2. Select your iPhone as the destination
3. Click Run (⌘R)

**Note:** If this is your first time installing an app from this developer:
- Go to Settings → General → VPN & Device Management on your iPhone
- Trust your developer certificate

## Usage

### Initial Setup

1. Launch the app
2. Tap "Configure SMB Settings"
3. Enter your SMB server details:
   - **Server Address**: IP address (e.g., `192.168.1.100`)
   - **Share Name**: SMB share name (e.g., `photos`)
   - **Username**: SMB username
   - **Password**: SMB password
   - **Remote Path**: Destination folder (e.g., `iPhone/2024`)
4. Tap "Test Connection" to verify
5. Tap "Save"

### Manual Sync

1. Open the app
2. Tap "Start Sync"
3. Grant photo library access when prompted
4. Monitor progress as photos upload

### Background Sync

1. Go to Settings in the app
2. Enable "Background Sync"
3. Choose sync interval (1-12 hours)
4. Optionally enable "WiFi Only" mode

**Note:** iOS background sync works best when combined with Shortcuts automations for immediate syncing.

### Shortcuts Automation

Create automated workflows using the "Sync Photos to SMB" action:

**Examples:**
- Sync when connecting to home WiFi
- Sync at specific times of day
- Trigger with Back Tap gesture
- Add to home screen widget

## Project Structure

```
SMBPhotoSync/
├── SMBPhotoSync.xcodeproj     # Xcode project file
└── SMBPhotoSync/              # Source code
    ├── SMBPhotoSyncApp.swift  # App entry point
    ├── Models/                # Data models
    │   ├── SMBCredentials.swift
    │   └── SyncProgress.swift
    ├── Services/              # Core functionality
    │   ├── BackgroundSyncManager.swift
    │   ├── KeychainManager.swift
    │   ├── PhotoLibraryManager.swift
    │   ├── SMBManager.swift
    │   └── SyncEngine.swift
    ├── Views/                 # UI components
    │   ├── SyncView.swift
    │   ├── SettingsView.swift
    │   ├── ProgressListView.swift
    │   └── DebugLogsView.swift
    ├── Intents/               # Shortcuts integration
    │   └── SyncPhotosIntent.swift
    └── Assets.xcassets/       # App icons and images
```

## How It Works

1. **Remote Scanning**: Scans SMB directory for existing files to avoid duplicates
2. **Unique Filenames**: Names photos as `YYYYMMDD_HHmmss_[ID].[ext]`
   Example: `20241221_143022_ABC123EF.jpg`
3. **Parallel Upload**: Uploads up to 10 photos concurrently
4. **Smart Retry**: Automatically retries failed uploads up to 3 times
5. **Secure Storage**: Credentials encrypted in iOS Keychain

## Troubleshooting

### App Expires After 7 Days
Free Apple IDs require weekly re-signing. Simply rebuild from Xcode (takes ~30 seconds). Your settings are preserved.

### Connection Failed
- Verify iPhone is on same network as SMB server
- Check server IP address and share name
- Ensure credentials are correct
- Test SMB access from a computer first

### Background Sync Not Working
- iOS limits background tasks - combine with Shortcuts automations for best results
- Check Background App Refresh is enabled in Settings
- WiFi Only mode requires WiFi connection

### Photos Not Uploading
- Grant photo library permission in Settings → Privacy
- Verify write permissions on SMB share
- Check remote path exists or can be created

## Privacy & Security

- **No Cloud**: All syncing happens directly between your iPhone and SMB server
- **Encrypted Storage**: Credentials stored in iOS Keychain
- **Local Only**: No third-party services or analytics
- **Minimal Permissions**: Only requests photo library and local network access

## Technical Details

- **Language**: Swift 5.0
- **Framework**: SwiftUI
- **Concurrency**: Swift Concurrency (async/await, actors)
- **SMB Library**: [AMSMB2](https://github.com/amosavian/AMSMB2)
- **Minimum iOS**: 16.0
- **Architecture**: MVVM with actor-based concurrency

## License

This is personal use software. Feel free to use and modify as needed.

## Support

For technical issues:
- AMSMB2: https://github.com/amosavian/AMSMB2
- Apple PhotoKit: https://developer.apple.com/documentation/photokit
- iOS Shortcuts: https://developer.apple.com/documentation/appintents
