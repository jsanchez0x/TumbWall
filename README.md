# TumbWall

## Overview
TumbWall is a native macOS application for downloading wallpapers from Tumblr blogs. It features a hybrid download engine (API + Scraping), resolution filtering, and concurrent downloads.

## Architecture
- **Language**: Swift 5.9+
- **UI Framework**: SwiftUI
- **Pattern**: MVVM + Clean Architecture
- **Concurrency**: Swift Concurrency (`async/await`) + `OperationQueue` for rate limiting.

## Setup Instructions

### 1. Dependencies
This project uses **Swift Package Manager**.
- **SwiftSoup**: Required for the Scraper strategy.
  - File > Add Package Dependencies...
  - URL: `https://github.com/scinfu/SwiftSoup.git`
  - Version: `2.6.0` or later.

### 2. Permissions & Sandboxing
To allow the app to download files and access the internet, update your target's **Signing & Capabilities**:

#### App Sandbox
Ensure the following are checked:
- **Network**:
  - [x] Incoming Connections (Server)
  - [x] Outgoing Connections (Client)
- **File Access**:
  - **User Selected File**: Read/Write (Required to save images to the selected folder).

#### Info.plist / Entitlements
If editing manually, ensure these keys are present in your `.entitlements` file:

```xml
<key>com.apple.security.network.client</key>
<true/>
<key>com.apple.security.files.user-selected.read-write</key>
<true/>
```

### 3. Usage
1. **Settings**:
   - (Optional) Add your Tumblr API Key in `Settings -> Tumblr API`.
   - Configure User Agent if needed.
2. **Main Screen**:
   - Enter `blogname.tumblr.com`.
   - Select minimum resolution (HUD, 4K).
   - Click "Select Folder" to choose download destination.
   - Click "Start Download".

## Testing
Run the Test scheme (`Cmd+U`) to verify networking logic and configuration persistence.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
