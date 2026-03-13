import Foundation

@MainActor
class LaunchdServiceManager: ObservableObject {
    static let shared = LaunchdServiceManager()

    @Published var services: [ServiceItem] = []
    @Published var isLoading = false
    @Published var lastError: String?

    private init() {}

    // MARK: - List Services

    func refreshServices(includeSystem: Bool = false) async {
        isLoading = true
        lastError = nil

        do {
            let output = try await ShellRunner.runIgnoringExitCode("/bin/launchctl", arguments: ["list"])
            services = parseLaunchctlOutput(output, filterApple: !includeSystem)
        } catch {
            lastError = "Failed to list launchd services: \(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - Service Actions

    func startService(_ service: ServiceItem) async -> Bool {
        await runLaunchctl(["kickstart", "-k", domainTarget(for: service)])
    }

    func stopService(_ service: ServiceItem) async -> Bool {
        await runLaunchctl(["kill", "SIGTERM", domainTarget(for: service)])
    }

    func restartService(_ service: ServiceItem) async -> Bool {
        _ = await stopService(service)
        try? await Task.sleep(nanoseconds: 500_000_000)
        let started = await startService(service)
        await refreshServices(includeSystem: SettingsManager.shared.settings.showSystemLaunchdServices)
        return started
    }

    // MARK: - Domain Path

    private func domainTarget(for service: ServiceItem) -> String {
        service.user ? "gui/\(getuid())/\(service.label)" : "system/\(service.label)"
    }

    // MARK: - Parse launchctl list

    private func parseLaunchctlOutput(_ output: String, filterApple: Bool) -> [ServiceItem] {
        var items: [ServiceItem] = []
        let lines = output.components(separatedBy: "\n")

        for line in lines.dropFirst() { // Skip header "PID\tStatus\tLabel"
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            let columns = trimmed.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
            guard columns.count >= 3 else { continue }

            let pidStr = columns[0].trimmingCharacters(in: .whitespaces)
            let statusStr = columns[1].trimmingCharacters(in: .whitespaces)
            let label = columns[2].trimmingCharacters(in: .whitespaces)

            if filterApple && label.hasPrefix("com.apple.") {
                continue
            }

            let status: ServiceStatus
            if pidStr != "-" && Int(pidStr) != nil {
                status = .running
            } else if statusStr == "0" || statusStr == "-" {
                status = .stopped
            } else {
                status = .error
            }

            items.append(ServiceItem(
                name: label,
                type: .launchd,
                status: status,
                label: label,
                user: true
            ))
        }

        return items.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    // MARK: - Shell Commands

    private func runLaunchctl(_ arguments: [String]) async -> Bool {
        do {
            _ = try await ShellRunner.runIgnoringExitCode("/bin/launchctl", arguments: arguments)
            return true
        } catch {
            lastError = "launchctl error: \(error.localizedDescription)"
            return false
        }
    }
}
