import Foundation
import Combine

@MainActor
class ServiceCoordinator: ObservableObject {
    static let shared = ServiceCoordinator()

    @Published var allServices: [ServiceItem] = []
    @Published var isLoading = false
    @Published var runningCount = 0

    private let brewManager = BrewServiceManager.shared
    private let launchdManager = LaunchdServiceManager.shared
    private let settings = SettingsManager.shared

    private var refreshTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    private init() {
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

    deinit {
        refreshTimer?.invalidate()
    }

    // MARK: - Refresh

    func refreshAll() async {
        let showBrew = settings.settings.showBrewServices && brewManager.isBrewInstalled
        let showLaunchd = settings.settings.showLaunchdServices
        let includeSystem = settings.settings.showSystemLaunchdServices

        async let brewRefresh: () = {
            if showBrew { await self.brewManager.refreshServices() }
        }()
        async let launchdRefresh: () = {
            if showLaunchd { await self.launchdManager.refreshServices(includeSystem: includeSystem) }
        }()

        _ = await (brewRefresh, launchdRefresh)
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

    // MARK: - Private

    private func mergeServices(brew: [ServiceItem], launchd: [ServiceItem]) {
        var merged: [ServiceItem] = []
        if settings.settings.showBrewServices {
            merged.append(contentsOf: brew)
        }
        if settings.settings.showLaunchdServices {
            merged.append(contentsOf: launchd)
        }

        // Skip update if nothing changed
        guard merged != allServices else { return }
        allServices = merged
        runningCount = merged.filter { $0.status == .running }.count
    }
}
