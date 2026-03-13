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
            var allServices: [ServiceItem] = []

            // User-level agents
            let userServices = try await listLaunchdServices(domain: "user", isUser: true)
            allServices.append(contentsOf: userServices)

            // System-level daemons (optional)
            if includeSystem {
                let systemServices = try await listLaunchdServices(domain: "system", isUser: false)
                allServices.append(contentsOf: systemServices)
            }

            services = allServices
        } catch {
            lastError = "Failed to list launchd services: \(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - Service Actions

    func startService(_ service: ServiceItem) async -> Bool {
        if service.user {
            return await runLaunchctl(["kickstart", "-k", "gui/\(getuid())/\(service.label)"])
        } else {
            return await runLaunchctl(["kickstart", "-k", "system/\(service.label)"])
        }
    }

    func stopService(_ service: ServiceItem) async -> Bool {
        if service.user {
            return await runLaunchctl(["kill", "SIGTERM", "gui/\(getuid())/\(service.label)"])
        } else {
            return await runLaunchctl(["kill", "SIGTERM", "system/\(service.label)"])
        }
    }

    func restartService(_ service: ServiceItem) async -> Bool {
        let stopped = await stopService(service)
        if stopped {
            // Small delay to let the service stop
            try? await Task.sleep(nanoseconds: 500_000_000)
        }
        let started = await startService(service)
        await refreshServices(includeSystem: SettingsManager.shared.settings.showSystemLaunchdServices)
        return started
    }

    // MARK: - Parse launchctl list

    private func listLaunchdServices(domain: String, isUser: Bool) async throws -> [ServiceItem] {
        let output: String
        if isUser {
            output = try await runCommand("/bin/launchctl", arguments: ["list"])
        } else {
            output = try await runCommand("/bin/launchctl", arguments: ["list"])
        }

        return parseLaunchctlOutput(output, isUser: isUser)
    }

    private func parseLaunchctlOutput(_ output: String, isUser: Bool) -> [ServiceItem] {
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

            // Skip Apple internal services for cleaner list
            if label.hasPrefix("com.apple.") && !SettingsManager.shared.settings.showSystemLaunchdServices {
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

            let item = ServiceItem(
                name: label,
                type: .launchd,
                status: status,
                label: label,
                user: isUser
            )
            items.append(item)
        }

        return items.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    // MARK: - Shell Commands

    private func runLaunchctl(_ arguments: [String]) async -> Bool {
        do {
            _ = try await runCommand("/bin/launchctl", arguments: arguments)
            return true
        } catch {
            lastError = "launchctl error: \(error.localizedDescription)"
            return false
        }
    }

    private func runCommand(_ path: String, arguments: [String]) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                let pipe = Pipe()
                let errorPipe = Pipe()

                process.executableURL = URL(fileURLWithPath: path)
                process.arguments = arguments
                process.standardOutput = pipe
                process.standardError = errorPipe

                do {
                    try process.run()
                    process.waitUntilExit()

                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    let output = String(data: data, encoding: .utf8) ?? ""

                    // launchctl sometimes returns non-zero for operations that succeed
                    continuation.resume(returning: output)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
