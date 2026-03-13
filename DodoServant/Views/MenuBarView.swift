import SwiftUI

struct MenuBarView: View {
    @ObservedObject private var coordinator = ServiceCoordinator.shared
    @ObservedObject private var settings = SettingsManager.shared
    @State private var searchText = ""
    @State private var hoveredServiceId: String?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            Divider()

            // Search
            searchBar

            // Content
            ScrollView {
                VStack(spacing: 0) {
                    if coordinator.isLoading && coordinator.allServices.isEmpty {
                        loadingView
                    } else if filteredServices.isEmpty && !searchText.isEmpty {
                        emptySearchView
                    } else {
                        // Pinned services
                        if !pinnedFiltered.isEmpty {
                            sectionHeader("Pinned")
                            ForEach(pinnedFiltered) { service in
                                ServiceRowView(
                                    service: service,
                                    isHovered: hoveredServiceId == service.id
                                )
                                .onHover { isHovered in
                                    hoveredServiceId = isHovered ? service.id : nil
                                }
                            }

                            if !unpinnedFiltered.isEmpty {
                                Divider()
                                    .padding(.vertical, 4)
                            }
                        }

                        // All services
                        if !unpinnedFiltered.isEmpty {
                            sectionHeader(searchText.isEmpty ? "All services" : "Results")
                            ForEach(unpinnedFiltered) { service in
                                ServiceRowView(
                                    service: service,
                                    isHovered: hoveredServiceId == service.id
                                )
                                .onHover { isHovered in
                                    hoveredServiceId = isHovered ? service.id : nil
                                }
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            .frame(maxHeight: 400)

            Divider()

            // Footer
            footerView
        }
        .frame(width: 320)
        .task {
            await coordinator.refreshAll()
            coordinator.startAutoRefresh()
        }
    }

    // MARK: - Subviews

    private var headerView: some View {
        HStack {
            Image(systemName: "server.rack")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.accentColor)
            Text("DodoServant")
                .font(.system(size: 14, weight: .semibold))

            Spacer()

            // Running count badge
            Text("\(coordinator.runningServices.count) running")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.green.opacity(0.15))
                .cornerRadius(4)

            Button(action: {
                Task { await coordinator.refreshAll() }
            }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11))
            }
            .buttonStyle(.borderless)
            .help("Refresh services")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var searchBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            TextField("Search services...", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(6)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private var loadingView: some View {
        VStack(spacing: 8) {
            ProgressView()
                .scaleEffect(0.8)
            Text("Loading services...")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private var emptySearchView: some View {
        VStack(spacing: 4) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 20))
                .foregroundColor(.secondary)
            Text("No services found")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
    }

    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.top, 6)
        .padding(.bottom, 2)
    }

    private var footerView: some View {
        HStack {
            Text("\(coordinator.allServices.count) services")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Filtering

    private var filteredServices: [ServiceItem] {
        if searchText.isEmpty {
            return coordinator.allServices
        }
        return coordinator.allServices.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.label.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var pinnedFiltered: [ServiceItem] {
        filteredServices.filter { settings.isPinned($0) }
    }

    private var unpinnedFiltered: [ServiceItem] {
        filteredServices.filter { !settings.isPinned($0) }
    }
}

// MARK: - Service Row View

struct ServiceRowView: View {
    let service: ServiceItem
    let isHovered: Bool

    @ObservedObject private var coordinator = ServiceCoordinator.shared
    @ObservedObject private var settings = SettingsManager.shared
    @State private var isActionInProgress = false

    var body: some View {
        HStack(spacing: 8) {
            // Status indicator
            Image(systemName: service.status.icon)
                .font(.system(size: 8))
                .foregroundColor(statusColor)

            // Service info
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(service.name)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)

                    if settings.isPinned(service) {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 8))
                            .foregroundColor(.orange)
                    }
                }

                HStack(spacing: 4) {
                    Text(service.type.rawValue)
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)

                    if service.type == .launchd && !service.user {
                        Text("system")
                            .font(.system(size: 9))
                            .foregroundColor(.orange)
                    }
                }
            }

            Spacer()

            // Action buttons (visible on hover)
            if isHovered || isActionInProgress {
                actionButtons
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(isHovered ? Color(nsColor: .controlBackgroundColor) : Color.clear)
        .cornerRadius(4)
        .contextMenu {
            contextMenuItems
        }
    }

    private var statusColor: Color {
        switch service.status {
        case .running: return .green
        case .stopped: return .secondary
        case .error: return .red
        case .unknown: return .orange
        }
    }

    @ViewBuilder
    private var actionButtons: some View {
        if isActionInProgress {
            ProgressView()
                .scaleEffect(0.5)
                .frame(width: 20, height: 20)
        } else {
            HStack(spacing: 2) {
                if service.status == .running {
                    Button(action: { performAction { await coordinator.restartService(service) } }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 10))
                    }
                    .buttonStyle(.borderless)
                    .help("Restart")

                    Button(action: { performAction { await coordinator.stopService(service) } }) {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 9))
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.borderless)
                    .help("Stop")
                } else {
                    Button(action: { performAction { await coordinator.startService(service) } }) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.green)
                    }
                    .buttonStyle(.borderless)
                    .help("Start")
                }
            }
        }
    }

    @ViewBuilder
    private var contextMenuItems: some View {
        if service.status == .running {
            Button("Restart") { performAction { await coordinator.restartService(service) } }
            Button("Stop") { performAction { await coordinator.stopService(service) } }
        } else {
            Button("Start") { performAction { await coordinator.startService(service) } }
        }

        Divider()

        Button(settings.isPinned(service) ? "Unpin" : "Pin") {
            settings.togglePin(service)
        }

        Divider()

        Button("Copy name") {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(service.name, forType: .string)
        }
    }

    private func performAction(_ action: @escaping () async -> Bool) {
        isActionInProgress = true
        Task {
            _ = await action()
            isActionInProgress = false
        }
    }
}
