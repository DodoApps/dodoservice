import Foundation

// MARK: - Appearance Mode

enum AppearanceMode: String, Codable, CaseIterable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"
}

// MARK: - App Settings

struct AppSettings: Codable {
    var launchAtStartup: Bool
    var appearanceMode: AppearanceMode
    var pinnedServiceIds: [String]
    var showInDock: Bool
    var refreshInterval: TimeInterval // seconds
    var showBrewServices: Bool
    var showLaunchdServices: Bool
    var showSystemLaunchdServices: Bool

    static let `default` = AppSettings(
        launchAtStartup: false,
        appearanceMode: .system,
        pinnedServiceIds: [],
        showInDock: false,
        refreshInterval: 10,
        showBrewServices: true,
        showLaunchdServices: true,
        showSystemLaunchdServices: false
    )
}
