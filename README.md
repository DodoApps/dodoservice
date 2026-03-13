# DodoService

A lightweight, native macOS menu bar app for managing your Homebrew and Launchd services.

## Features

- **Homebrew services** — List, start, stop, and restart brew services
- **Launchd services** — Manage user-level and system-level launchd agents/daemons
- **Smart categories** — Services are auto-grouped into Databases, Web servers, Cache & queues, Runtimes, and Other
- **Collapsible sections** — Click category headers to expand/collapse (accordion)
- **Pin favorites** — Pin frequently used services to the top for quick access
- **Status at a glance** — Summary cards showing running, stopped, and total service counts
- **Tab filtering** — Switch between All, Homebrew, and Launchd views
- **Search** — Instantly filter services by name
- **Auto-refresh** — Configurable refresh interval (5s / 10s / 30s / 60s)
- **Service actions** — Start, stop, restart with hover-activated buttons
- **Dark / Light / System** theme support
- **Launch at login** — Start DodoService automatically when you log in

## Requirements

- macOS 14.0+ (Sonoma)
- Xcode 15+ (for building from source)
- Homebrew (optional, for brew service management)

## Installation

### From release

Download the latest `DodoService.app` from [Releases](https://github.com/DodoApps/dodoservice/releases), move it to `/Applications`, and open it.

### Build from source

```bash
git clone https://github.com/DodoApps/dodoservice.git
cd dodoservice
xcodebuild -project DodoService.xcodeproj -scheme DodoService -configuration Release archive -archivePath build/DodoService.xcarchive
xcodebuild -exportArchive -archivePath build/DodoService.xcarchive -exportPath release/ -exportOptionsPlist exportOptions.plist
cp -R release/DodoService.app /Applications/
```

Or open `DodoService.xcodeproj` in Xcode and press `Cmd+R`.

## Usage

DodoService lives in your menu bar. Click the server icon to open the popover:

- **Left-click** — Opens the service manager popover
- **Right-click** — Context menu with appearance, settings, and quit options
- **Hover a service** — Action buttons appear (start/stop/restart)
- **Right-click a service** — Pin, copy name, or perform actions
- **Click a category header** — Collapse/expand that section

## Architecture

Native macOS menu bar app built with SwiftUI + AppKit. See [CLAUDE.md](CLAUDE.md) for development details.

## License

[MIT](LICENSE)
