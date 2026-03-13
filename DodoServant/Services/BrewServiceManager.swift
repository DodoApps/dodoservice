import Foundation

@MainActor
class BrewServiceManager: ObservableObject {
    static let shared = BrewServiceManager()

    @Published var services: [ServiceItem] = []
    @Published var isLoading = false
    @Published var lastError: String?

    private var brewPath: String?

    private init() {
        brewPath = findBrewPath()
    }

    // MARK: - Brew Path Detection

    private func findBrewPath() -> String? {
        let possiblePaths = [
            "/opt/homebrew/bin/brew",  // Apple Silicon
            "/usr/local/bin/brew"       // Intel
        ]
        for path in possiblePaths {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }
        return nil
    }

    var isBrewInstalled: Bool {
        brewPath != nil
    }

    // MARK: - List Services

    func refreshServices() async {
        guard let brewPath = brewPath else { return }

        isLoading = true
        lastError = nil

        var env = ProcessInfo.processInfo.environment
        env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:" + (env["PATH"] ?? "")

        do {
            let output = try await ShellRunner.run(brewPath, arguments: ["services", "list"], env: env)
            services = parseBrewServicesOutput(output)
        } catch {
            lastError = "Failed to list brew services: \(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - Service Actions

    func startService(_ service: ServiceItem) async -> Bool {
        await runServiceAction("start", service: service)
    }

    func stopService(_ service: ServiceItem) async -> Bool {
        await runServiceAction("stop", service: service)
    }

    func restartService(_ service: ServiceItem) async -> Bool {
        await runServiceAction("restart", service: service)
    }

    private func runServiceAction(_ action: String, service: ServiceItem) async -> Bool {
        guard let brewPath = brewPath else { return false }

        var env = ProcessInfo.processInfo.environment
        env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:" + (env["PATH"] ?? "")

        do {
            _ = try await ShellRunner.run(brewPath, arguments: ["services", action, service.name], env: env)
            await refreshServices()
            return true
        } catch {
            lastError = "Failed to \(action) \(service.name): \(error.localizedDescription)"
            return false
        }
    }

    // MARK: - Parse Output

    private func parseBrewServicesOutput(_ output: String) -> [ServiceItem] {
        var items: [ServiceItem] = []
        let lines = output.components(separatedBy: "\n")

        for line in lines.dropFirst() { // Skip header
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            let columns = trimmed.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
            guard columns.count >= 2 else { continue }

            let name = columns[0]
            let statusStr = columns[1].lowercased()

            let status: ServiceStatus
            switch statusStr {
            case "started": status = .running
            case "stopped", "none": status = .stopped
            case "error": status = .error
            default: status = .unknown
            }

            let item = ServiceItem(
                name: name,
                type: .brew,
                status: status,
                label: name,
                user: true
            )
            items.append(item)
        }

        return items
    }
}
