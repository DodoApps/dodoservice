import Foundation
import Combine

/// Coordinates both Brew and Launchd service managers into a unified service list
@MainActor
class ServiceCoordinator: ObservableObject {
    static let shared = ServiceCoordinator()

    @Published var allServices: [ServiceItem] = []
    @Published var isLoading = false

    private let brewManager = BrewServiceManager.shared
    private let launchdManager = LaunchdServiceManager.shared
    private let settings = SettingsManager.shared

    private var refreshTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    private init() {
        // Observe changes from both managers
        brewManager.$services
            .combineLatest(launchdManager.$services)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] brew, launchd in
                self?.mergeServices(brew: brew, launchd: launchd)
            }
            .store(in: &cancellables)

        brewManager.$isLoading
            .combineLatest(launchdManager.$isLoading)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] brewLoading, launchdLoading in
                self?.isLoading = brewLoading || launchdLoading
            }
            .store(in: &cancellables)
    }

    // MARK: - Refresh

    func refreshAll() async {
        let showBrew = settings.settings.showBrewServices && brewManager.isBrewInstalled
        let showLaunchd = settings.settings.showLaunchdServices
        let includeSystem = settings.settings.showSystemLaunchdServices

        if showBrew {
            await brewManager.refreshServices()
        }
        if showLaunchd {
            await launchdManager.refreshServices(includeSystem: includeSystem)
        }
    }

    func startAutoRefresh() {
        stopAutoRefresh()
        let interval = settings.settings.refreshInterval
        refreshTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.refreshAll()
            }
        }
    }

    func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    // MARK: - Service Actions

    func startService(_ service: ServiceItem) async -> Bool {
        switch service.type {
        case .brew:
            return await brewManager.startService(service)
        case .launchd:
            return await launchdManager.startService(service)
        }
    }

    func stopService(_ service: ServiceItem) async -> Bool {
        switch service.type {
        case .brew:
            return await brewManager.stopService(service)
        case .launchd:
            return await launchdManager.stopService(service)
        }
    }

    func restartService(_ service: ServiceItem) async -> Bool {
        switch service.type {
        case .brew:
            return await brewManager.restartService(service)
        case .launchd:
            return await launchdManager.restartService(service)
        }
    }

    // MARK: - Filtered Lists

    var pinnedServices: [ServiceItem] {
        allServices.filter { settings.isPinned($0) }
    }

    var unpinnedServices: [ServiceItem] {
        allServices.filter { !settings.isPinned($0) }
    }

    var runningServices: [ServiceItem] {
        allServices.filter { $0.status == .running }
    }

    // MARK: - Private

    private func mergeServices(brew: [ServiceItem], launchd: [ServiceItem]) {
        var merged: [ServiceItem] = []
        if settings.settings.showBrewServices {
            merged.append(contentsOf: brew)
        }
        if settings.settings.showLaunchdServices {
            merged.append(contentsOf: launchd)
        }
        allServices = merged
    }
}
