import Foundation
import ServiceManagement

class LaunchAtLoginManager {
    static let shared = LaunchAtLoginManager()

    private init() {}

    var isEnabled: Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        } else {
            return SettingsManager.shared.settings.launchAtStartup
        }
    }

    func setEnabled(_ enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("Failed to \(enabled ? "enable" : "disable") launch at login: \(error)")
            }
        }
    }

    func syncWithSystemState() {
        if #available(macOS 13.0, *) {
            let isSystemEnabled = SMAppService.mainApp.status == .enabled
            if SettingsManager.shared.settings.launchAtStartup != isSystemEnabled {
                SettingsManager.shared.settings.launchAtStartup = isSystemEnabled
            }
        }
    }
}
