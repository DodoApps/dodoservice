import SwiftUI
import AppKit

@main
struct DodoServiceApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

extension Notification.Name {
    static let openSettings = Notification.Name("openSettings")
}

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var settingsWindow: NSWindow?
    private var settingsCloseObserver: Any?
    private var settingsNotificationObserver: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Set activation policy based on user preference
        let showInDock = SettingsManager.shared.settings.showInDock
        NSApp.setActivationPolicy(showInDock ? .regular : .accessory)

        // Setup menu bar
        setupMenuBar()

        // Start auto-refresh timer
        Task {
            await ServiceCoordinator.shared.refreshAll()
            ServiceCoordinator.shared.startAutoRefresh()
        }

        // Sync launch at login state
        LaunchAtLoginManager.shared.syncWithSystemState()

        // Listen for settings open requests from SwiftUI views
        settingsNotificationObserver = NotificationCenter.default.addObserver(
            forName: .openSettings,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.openSettingsWindow()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    // MARK: - Menu Bar Setup

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            let config = NSImage.SymbolConfiguration(pointSize: 12, weight: .medium)
            if let image = NSImage(systemSymbolName: "server.rack", accessibilityDescription: "DodoService")?.withSymbolConfiguration(config) {
                image.isTemplate = true
                button.image = image
            }
            button.action = #selector(handleStatusItemClick)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        // Create popover
        popover = NSPopover()
        popover.contentSize = NSSize(width: 320, height: 480)
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = NSHostingController(rootView: MenuBarView())
    }

    @objc private func handleStatusItemClick() {
        guard let event = NSApp.currentEvent else { return }

        if event.type == .rightMouseUp {
            showContextMenu()
        } else {
            togglePopover()
        }
    }

    private func showContextMenu() {
        let menu = NSMenu()

        // Appearance submenu
        let appearanceMenu = NSMenu()
        let darkItem = NSMenuItem(title: "Dark", action: #selector(setDarkMode), keyEquivalent: "")
        let lightItem = NSMenuItem(title: "Light", action: #selector(setLightMode), keyEquivalent: "")
        let systemItem = NSMenuItem(title: "System", action: #selector(setSystemMode), keyEquivalent: "")

        darkItem.target = self
        lightItem.target = self
        systemItem.target = self

        let currentMode = SettingsManager.shared.settings.appearanceMode
        darkItem.state = currentMode == .dark ? .on : .off
        lightItem.state = currentMode == .light ? .on : .off
        systemItem.state = currentMode == .system ? .on : .off

        appearanceMenu.addItem(darkItem)
        appearanceMenu.addItem(lightItem)
        appearanceMenu.addItem(systemItem)

        let appearanceMenuItem = NSMenuItem(title: "Appearance", action: nil, keyEquivalent: "")
        appearanceMenuItem.submenu = appearanceMenu

        menu.addItem(appearanceMenuItem)
        menu.addItem(NSMenuItem.separator())

        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit DodoService", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func setDarkMode() {
        SettingsManager.shared.settings.appearanceMode = .dark
    }

    @objc private func setLightMode() {
        SettingsManager.shared.settings.appearanceMode = .light
    }

    @objc private func setSystemMode() {
        SettingsManager.shared.settings.appearanceMode = .system
    }

    @objc private func openSettings() {
        openSettingsWindow()
    }

    @objc func openSettingsWindow() {
        if popover.isShown {
            popover.performClose(nil)
        }

        if settingsWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 460, height: 360),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.title = "DodoService Settings"
            window.center()
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: SettingsView())
            settingsWindow = window
        }

        // For menu bar apps (LSUIElement), temporarily become a regular app
        // so the settings window can receive focus properly
        NSApp.setActivationPolicy(.regular)
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        // Observe window close to revert activation policy (only once)
        if settingsCloseObserver == nil {
            settingsCloseObserver = NotificationCenter.default.addObserver(
                forName: NSWindow.willCloseNotification,
                object: settingsWindow,
                queue: .main
            ) { [weak self] _ in
                let showInDock = SettingsManager.shared.settings.showInDock
                NSApp.setActivationPolicy(showInDock ? .regular : .accessory)
                if let observer = self?.settingsCloseObserver {
                    NotificationCenter.default.removeObserver(observer)
                    self?.settingsCloseObserver = nil
                }
            }
        }
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }
}

// MARK: - Appearance Extension

extension View {
    func applyAppTheme() -> some View {
        self.preferredColorScheme(SettingsManager.shared.settings.appearanceMode.colorScheme)
    }
}

extension AppearanceMode {
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}
