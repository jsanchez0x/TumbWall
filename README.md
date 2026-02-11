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

## macOS Security Note (Sequoia & newer)

Since the application is not currently signed with an Apple Developer certificate, macOS will block it from running the first time.

To authorize and open the app:
1. Open **TumbWall.app**. When the security alert appears, click **OK**.
2. Go to **System Settings** > **Privacy & Security**.
3. Scroll down to the **Security** section.
4. You will see a message: `"TumbWall" was blocked from use because it is not from an identified developer.`
5. Click **Open Anyway**.
6. Enter your Mac password (or use Touch ID) if prompted.
7. Click **Open** one last time in the final confirmation dialog.

After this initial authorization, the app will open normally by double-clicking.

## Features
- **Hybrid Engine**: Seamlessly switch between Tumblr API and Web Scraping.
- **Unlimited Paging**: Automatically fetch all available images from a blog until the end or manual stop.
- **Resolution Filtering**: Filter images by minimum width and height. Includes presets (HD, 4K) and **Custom Resolution** support for specific dimensions.
- **Smart Folder Management**: Select or **create new folders** directly from the download dialog.
- **Concurrent Downloads**: High-performance downloading with configurable concurrency limits.
- **macOS System Settings Style**: Polished and modern settings interface that feels native to macOS.
- **Real-time Logs**: Monitor the download process with detailed status updates.

## Setup Instructions
### 3. Usage
1. **Settings**:
   - (Optional) Add your Tumblr API Key in `Settings -> Tumblr API`.
   - Configure User Agent and maximum concurrent downloads in the native-style settings view.
2. **Main Screen**:
   - Enter `blogname.tumblr.com` or the full URL.
   - Select minimum resolution. Choose **Custom** to enter specific **minimum width and height** in pixels.
   - Click "Select Folder" to choose or **create** the download destination.
   - Click "Start Download" (The button will be enabled once a valid URL and folder are provided).

## Testing
Run the Test scheme (`Cmd+U`) to verify networking logic and configuration persistence.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
