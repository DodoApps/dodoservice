import Foundation

// MARK: - Service Type

enum ServiceType: String, Codable, CaseIterable {
    case brew
    case launchd

    var displayName: String {
        switch self {
        case .brew: return "Homebrew"
        case .launchd: return "Launchd"
        }
    }

    var icon: String {
        switch self {
        case .brew: return "mug"
        case .launchd: return "gear"
        }
    }
}

// MARK: - Service Status

enum ServiceStatus: String, Codable {
    case running = "Running"
    case stopped = "Stopped"
    case error = "Error"
    case unknown = "Unknown"

    var icon: String {
        switch self {
        case .running: return "circle.fill"
        case .stopped: return "circle"
        case .error: return "exclamationmark.circle.fill"
        case .unknown: return "questionmark.circle"
        }
    }
}

// MARK: - Service Item

struct ServiceItem: Identifiable, Codable, Hashable {
    var id: String { "\(type.rawValue):\(name)" }
    let name: String
    let type: ServiceType
    var status: ServiceStatus
    var label: String // Full label for launchd, service name for brew
    var user: Bool // true = user-level, false = system-level (launchd only)
    var plistPath: String? // Path to plist for launchd services

    init(name: String, type: ServiceType, status: ServiceStatus, label: String, user: Bool = true, plistPath: String? = nil) {
        self.name = name
        self.type = type
        self.status = status
        self.label = label
        self.user = user
        self.plistPath = plistPath
    }

    /// Display-friendly name (strips common prefixes)
    var displayName: String {
        if type == .launchd {
            // Strip common prefixes like com.apple., org.homebrew., etc.
            let parts = name.split(separator: ".")
            if parts.count > 2 {
                return String(parts.last ?? Substring(name))
            }
        }
        return name
    }
}
