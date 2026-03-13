import Foundation
import Combine
import AppKit

@MainActor
class SettingsManager: ObservableObject {
    static let shared = SettingsManager()

    @Published var settings: AppSettings {
        didSet {
            save()
            if oldValue.appearanceMode != settings.appearanceMode {
                applyAppearance()
            }
        }
    }

    /// Cached set for O(1) pin lookups
    private var pinnedSet: Set<String> = []

    private let userDefaults = UserDefaults.standard
    private let settingsKey = "DodoServiceSettings"

    private init() {
        if let data = userDefaults.data(forKey: settingsKey),
           let decoded = try? JSONDecoder().decode(AppSettings.self, from: data) {
            self.settings = decoded
        } else {
            self.settings = .default
        }
        pinnedSet = Set(settings.pinnedServiceIds)
        applyAppearance()
    }

    func save() {
        pinnedSet = Set(settings.pinnedServiceIds)
        if let encoded = try? JSONEncoder().encode(settings) {
            userDefaults.set(encoded, forKey: settingsKey)
        }
    }

    func reset() {
        settings = .default
        save()
    }

    func applyAppearance() {
        switch settings.appearanceMode {
        case .system:
            NSApp.appearance = nil
        case .light:
            NSApp.appearance = NSAppearance(named: .aqua)
        case .dark:
            NSApp.appearance = NSAppearance(named: .darkAqua)
        }
    }

    // MARK: - Pin Management

    func isPinned(_ service: ServiceItem) -> Bool {
        pinnedSet.contains(service.id)
    }

    func togglePin(_ service: ServiceItem) {
        if isPinned(service) {
            settings.pinnedServiceIds.removeAll { $0 == service.id }
        } else {
            settings.pinnedServiceIds.append(service.id)
        }
    }
}
