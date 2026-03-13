import Foundation
import SwiftUI

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
        case .launchd: return "gearshape.2"
        }
    }

    var color: Color {
        switch self {
        case .brew: return .orange
        case .launchd: return .blue
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

    var color: Color {
        switch self {
        case .running: return .green
        case .stopped: return Color(nsColor: .tertiaryLabelColor)
        case .error: return .red
        case .unknown: return .orange
        }
    }
}

// MARK: - Service Category

enum ServiceCategory: String, CaseIterable {
    case database = "Databases"
    case web = "Web servers"
    case cache = "Cache & queues"
    case runtime = "Runtimes"
    case other = "Other"

    var icon: String {
        switch self {
        case .database: return "cylinder"
        case .web: return "globe"
        case .cache: return "bolt.horizontal"
        case .runtime: return "terminal"
        case .other: return "ellipsis.circle"
        }
    }

    var color: Color {
        switch self {
        case .database: return .purple
        case .web: return .blue
        case .cache: return .red
        case .runtime: return .green
        case .other: return .gray
        }
    }

    static func categorize(_ name: String) -> ServiceCategory {
        let lower = name.lowercased()

        // Databases
        let dbKeywords = ["mysql", "postgres", "postgresql", "redis", "mongo", "mongodb",
                          "mariadb", "sqlite", "couchdb", "cassandra", "influxdb",
                          "cockroach", "supabase", "neo4j", "memcached"]
        if dbKeywords.contains(where: { lower.contains($0) }) { return .database }

        // Web servers
        let webKeywords = ["nginx", "apache", "httpd", "caddy", "traefik", "haproxy", "lighttpd", "tomcat"]
        if webKeywords.contains(where: { lower.contains($0) }) { return .web }

        // Cache & queues
        let cacheKeywords = ["rabbitmq", "kafka", "celery", "sidekiq", "zeromq",
                             "nats", "mqtt", "mosquitto", "varnish", "meilisearch",
                             "elasticsearch", "opensearch", "typesense"]
        if cacheKeywords.contains(where: { lower.contains($0) }) { return .cache }

        // Runtimes
        let runtimeKeywords = ["node", "python", "ruby", "php", "java", "go",
                               "deno", "bun", "dotnet", "erlang", "elixir"]
        if runtimeKeywords.contains(where: { lower.contains($0) }) { return .runtime }

        return .other
    }
}

// MARK: - Service Item

struct ServiceItem: Identifiable, Codable, Hashable {
    var id: String { "\(type.rawValue):\(name)" }
    let name: String
    let type: ServiceType
    var status: ServiceStatus
    var label: String
    var user: Bool
    var plistPath: String?

    init(name: String, type: ServiceType, status: ServiceStatus, label: String, user: Bool = true, plistPath: String? = nil) {
        self.name = name
        self.type = type
        self.status = status
        self.label = label
        self.user = user
        self.plistPath = plistPath
    }

    var displayName: String {
        if type == .launchd {
            let parts = name.split(separator: ".")
            if parts.count > 2 {
                return String(parts.last ?? Substring(name))
            }
        }
        return name
    }

    var category: ServiceCategory {
        ServiceCategory.categorize(name)
    }
}
