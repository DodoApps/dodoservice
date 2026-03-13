import SwiftUI

// MARK: - Main Menu Bar View

struct MenuBarView: View {
    @ObservedObject private var coordinator = ServiceCoordinator.shared
    @ObservedObject private var settings = SettingsManager.shared
    @State private var searchText = ""
    @State private var hoveredServiceId: String?
    @State private var selectedTab: ViewTab = .all
    @State private var isRefreshing = false

    enum ViewTab: String, CaseIterable {
        case all = "All"
        case brew = "Homebrew"
        case launchd = "Launchd"
    }

    var body: some View {
        VStack(spacing: 0) {
            headerSection
            statusCardsSection
            tabBar
            searchBar
            serviceListSection
            footerSection
        }
        .frame(width: 340)
        .background(Color(nsColor: .windowBackgroundColor))
        .task {
            await coordinator.refreshAll()
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            colors: [Color.teal.opacity(0.25), Color.green.opacity(0.15)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 32, height: 32)

                Image(systemName: "server.rack")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.teal, .green],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            VStack(alignment: .leading, spacing: 1) {
                Text("DodoServant")
                    .font(.system(size: 14, weight: .bold))
                Text("Service manager")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            Spacer()

            HeaderIconButton(icon: "arrow.clockwise", tooltip: "Refresh") {
                withAnimation(.easeInOut(duration: 0.3)) { isRefreshing = true }
                Task {
                    await coordinator.refreshAll()
                    withAnimation(.easeInOut(duration: 0.3)) { isRefreshing = false }
                }
            }
            .rotationEffect(.degrees(isRefreshing ? 360 : 0))

            HeaderIconButton(icon: "gearshape", tooltip: "Settings") {
                if let appDelegate = NSApp.delegate as? AppDelegate {
                    appDelegate.openSettingsWindow()
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    // MARK: - Status Cards

    private var statusCardsSection: some View {
        let running = coordinator.runningCount
        let stopped = coordinator.allServices.count - running

        return HStack(spacing: 8) {
            StatusCard(
                count: running,
                label: "Running",
                color: .green,
                icon: "checkmark.circle.fill"
            )
            StatusCard(
                count: stopped,
                label: "Stopped",
                color: Color(nsColor: .tertiaryLabelColor),
                icon: "moon.circle.fill"
            )
            StatusCard(
                count: coordinator.allServices.count,
                label: "Total",
                color: .blue,
                icon: "square.stack.fill"
            )
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 10)
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        HStack(spacing: 2) {
            ForEach(ViewTab.allCases, id: \.self) { tab in
                TabButton(title: tab.rawValue, isSelected: selectedTab == tab) {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        selectedTab = tab
                    }
                }
            }
        }
        .padding(3)
        .background(Color.primary.opacity(0.04))
        .cornerRadius(8)
        .padding(.horizontal, 14)
        .padding(.bottom, 6)
    }

    // MARK: - Search

    private var searchBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            TextField("Search services...", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.primary.opacity(0.04))
        .cornerRadius(6)
        .padding(.horizontal, 14)
        .padding(.bottom, 6)
    }

    // MARK: - Service List

    private var serviceListSection: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if coordinator.isLoading && coordinator.allServices.isEmpty {
                    loadingView
                } else if filteredAndGrouped.isEmpty {
                    emptyView
                } else {
                    // Pinned section
                    let pinned = filteredAndGrouped.flatMap(\.services).filter { settings.isPinned($0) }
                    if !pinned.isEmpty {
                        sectionDivider(label: "Pinned", icon: "pin.fill", color: .orange)
                        ForEach(pinned) { service in
                            ServiceRow(
                                service: service,
                                isHovered: hoveredServiceId == service.id
                            )
                            .onHover { h in hoveredServiceId = h ? service.id : nil }
                        }
                    }

                    // Categorized sections
                    ForEach(filteredAndGrouped, id: \.category) { group in
                        let unpinned = group.services.filter { !settings.isPinned($0) }
                        if !unpinned.isEmpty {
                            sectionDivider(
                                label: group.category.rawValue,
                                icon: group.category.icon,
                                color: group.category.color
                            )
                            ForEach(unpinned) { service in
                                ServiceRow(
                                    service: service,
                                    isHovered: hoveredServiceId == service.id
                                )
                                .onHover { h in hoveredServiceId = h ? service.id : nil }
                            }
                        }
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .frame(maxHeight: 350)
    }

    // MARK: - Footer

    private var footerSection: some View {
        HStack {
            Text("\(coordinator.allServices.count) services")
                .font(.system(size: 10))
                .foregroundColor(.secondary)

            Spacer()

            Button(action: { NSApplication.shared.terminate(nil) }) {
                Label("Quit", systemImage: "power")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .opacity(0.7)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.primary.opacity(0.03))
    }

    // MARK: - Helpers

    private var loadingView: some View {
        VStack(spacing: 10) {
            ProgressView()
                .scaleEffect(0.8)
            Text("Loading services...")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private var emptyView: some View {
        VStack(spacing: 6) {
            Image(systemName: searchText.isEmpty ? "tray" : "magnifyingglass")
                .font(.system(size: 24))
                .foregroundColor(.secondary.opacity(0.5))
            Text(searchText.isEmpty ? "No services" : "No results for \"\(searchText)\"")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
    }

    private func sectionDivider(label: String, icon: String, color: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(color.opacity(0.8))

            Text(label.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.secondary.opacity(0.7))
                .tracking(0.5)

            Rectangle()
                .fill(Color.primary.opacity(0.06))
                .frame(height: 1)
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 4)
    }

    // MARK: - Filtering & Grouping

    struct CategoryGroup {
        let category: ServiceCategory
        let services: [ServiceItem]
    }

    private var filteredAndGrouped: [CategoryGroup] {
        var filtered = coordinator.allServices

        // Tab filter
        switch selectedTab {
        case .brew: filtered = filtered.filter { $0.type == .brew }
        case .launchd: filtered = filtered.filter { $0.type == .launchd }
        case .all: break
        }

        // Search filter
        if !searchText.isEmpty {
            filtered = filtered.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.label.localizedCaseInsensitiveContains(searchText)
            }
        }

        // Group by category
        let grouped = Dictionary(grouping: filtered, by: { $0.category })
        return ServiceCategory.allCases.compactMap { cat in
            guard let services = grouped[cat], !services.isEmpty else { return nil }
            return CategoryGroup(category: cat, services: services.sorted { $0.name < $1.name })
        }
    }
}

// MARK: - Status Card

struct StatusCard: View {
    let count: Int
    let label: String
    let color: Color
    let icon: String

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundColor(color)
                Text("\(count)")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
            }
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(color.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(color.opacity(0.1), lineWidth: 1)
                )
        )
    }
}

// MARK: - Tab Button

struct TabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? .primary : .secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isSelected ? Color.primary.opacity(0.08) : Color.clear)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Header Icon Button

struct HeaderIconButton: View {
    let icon: String
    let tooltip: String
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(isHovered ? .primary : .secondary)
                .frame(width: 26, height: 26)
                .background(
                    Circle()
                        .fill(Color.primary.opacity(isHovered ? 0.1 : 0.04))
                )
        }
        .buttonStyle(.plain)
        .help(tooltip)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Service Row

struct ServiceRow: View {
    let service: ServiceItem
    let isHovered: Bool

    @ObservedObject private var coordinator = ServiceCoordinator.shared
    @ObservedObject private var settings = SettingsManager.shared
    @State private var isActionInProgress = false

    var body: some View {
        HStack(spacing: 10) {
            // Type icon with colored background
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(service.type.color.opacity(0.1))
                    .frame(width: 28, height: 28)

                Image(systemName: service.type.icon)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(service.type.color)
            }

            // Service info
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(service.displayName)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)

                    if settings.isPinned(service) {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 7))
                            .foregroundColor(.orange)
                    }
                }

                HStack(spacing: 4) {
                    // Status pill
                    HStack(spacing: 3) {
                        Circle()
                            .fill(service.status.color)
                            .frame(width: 5, height: 5)
                        Text(service.status.rawValue)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(service.status.color)
                    }

                    if service.type == .launchd && !service.user {
                        Text("system")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundColor(.orange)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.orange.opacity(0.12))
                            .cornerRadius(3)
                    }
                }
            }

            Spacer()

            // Action buttons
            if isHovered || isActionInProgress {
                actionButtons
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isHovered ? Color.primary.opacity(0.05) : Color.clear)
        )
        .animation(.easeInOut(duration: 0.12), value: isHovered)
        .contextMenu { contextMenuItems }
    }

    @ViewBuilder
    private var actionButtons: some View {
        if isActionInProgress {
            ProgressView()
                .scaleEffect(0.5)
                .frame(width: 24, height: 24)
        } else {
            HStack(spacing: 4) {
                if service.status == .running {
                    ActionButton(icon: "arrow.clockwise", color: .blue, tooltip: "Restart") {
                        performAction { await coordinator.restartService(service) }
                    }
                    ActionButton(icon: "stop.fill", color: .red, tooltip: "Stop") {
                        performAction { await coordinator.stopService(service) }
                    }
                } else {
                    ActionButton(icon: "play.fill", color: .green, tooltip: "Start") {
                        performAction { await coordinator.startService(service) }
                    }
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

        Button(settings.isPinned(service) ? "Unpin" : "Pin to top") {
            settings.togglePin(service)
        }

        Divider()

        Button("Copy name") {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(service.name, forType: .string)
        }

        if service.name != service.label {
            Button("Copy label") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(service.label, forType: .string)
            }
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

// MARK: - Action Button

struct ActionButton: View {
    let icon: String
    let color: Color
    let tooltip: String
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(isHovered ? .white : color)
                .frame(width: 22, height: 22)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(isHovered ? color : color.opacity(0.12))
                )
        }
        .buttonStyle(.plain)
        .help(tooltip)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovered = hovering
            }
        }
    }
}
