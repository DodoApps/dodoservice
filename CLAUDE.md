# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run

Open in Xcode and build with Cmd+R:
```bash
open DodoServant.xcodeproj
```

Command-line build:
```bash
xcodebuild -project DodoServant.xcodeproj -scheme DodoServant -configuration Debug build
```

Archive for release:
```bash
xcodebuild -project DodoServant.xcodeproj -scheme DodoServant -configuration Release archive -archivePath build/DodoServant.xcarchive
xcodebuild -exportArchive -archivePath build/DodoServant.xcarchive -exportPath release/ -exportOptionsPlist exportOptions.plist
```

There are no unit tests in this project. Requires Xcode 15+, macOS 14.0+ (Sonoma), Swift 5.9.

## Architecture

Native macOS menu bar app built with SwiftUI + AppKit. Runs as a menu bar item (NSStatusItem) with left-click popover and right-click context menu. Uses `NSApplicationDelegateAdaptor` in `DodoServantApp.swift` to bridge SwiftUI app lifecycle with AppKit window management.

### Singleton services (all use `static let shared`)

- **ServiceCoordinator** — Central coordinator that merges Brew and Launchd services into a unified list. Manages auto-refresh timer and delegates actions to the appropriate service manager.
- **BrewServiceManager** — Manages Homebrew services via `brew services` CLI. Handles listing, starting, stopping, and restarting brew services.
- **LaunchdServiceManager** — Manages launchd services via `launchctl` CLI. Supports both user-level and system-level services.
- **SettingsManager** — Persists `AppSettings` to UserDefaults as JSON. Settings auto-save on `didSet` and auto-apply appearance mode.
- **LaunchAtLoginManager** — Handles launch at login via SMAppService (macOS 13+).
- **ShellRunner** — Shared utility for running shell commands via Process. Used by both BrewServiceManager and LaunchdServiceManager.

### Key design decisions

- **Menu bar app with popover** — Left-click shows the service list popover, right-click shows context menu (appearance, settings, quit).
- **Pin system** — Users can pin frequently used services for quick access. Pinned service IDs stored in UserDefaults via AppSettings.
- **Auto-refresh** — Services list refreshes automatically at configurable intervals (5s/10s/30s/60s).
- **No sandbox** — App needs to run `brew` and `launchctl` commands, which require shell access.

### File structure

```
DodoServant/
├── DodoServantApp.swift          # App entry point + AppDelegate
├── Info.plist
├── DodoServant.entitlements
├── Models/
│   ├── AppSettings.swift         # Settings model + AppearanceMode enum
│   └── ServiceItem.swift         # ServiceItem, ServiceType, ServiceStatus
├── Services/
│   ├── BrewServiceManager.swift  # Homebrew service management
│   ├── LaunchdServiceManager.swift # Launchd service management
│   ├── LaunchAtLoginManager.swift  # Login item management
│   ├── ServiceCoordinator.swift  # Unified service coordinator
│   ├── SettingsManager.swift     # Settings persistence
│   └── ShellRunner.swift         # Shared shell command execution
└── Views/
    ├── MenuBarView.swift         # Main popover view + ServiceRowView
    └── Settings/
        └── SettingsView.swift    # Settings window tabs
```

## Code conventions

- Swift API Design Guidelines, SwiftUI for all views
- `@MainActor` on observable service classes
- MARK comments for section organization
- Bundle ID: `com.dodoservant.app`
