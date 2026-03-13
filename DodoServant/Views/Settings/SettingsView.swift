import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @ObservedObject private var settings = SettingsManager.shared

    var body: some View {
        TabView {
            GeneralSettingsTab()
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            ServicesSettingsTab()
                .tabItem {
                    Label("Services", systemImage: "server.rack")
                }

            AboutTab()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 420, height: 320)
    }
}

// MARK: - General Settings

struct GeneralSettingsTab: View {
    @ObservedObject private var settings = SettingsManager.shared

    var body: some View {
        Form {
            Section("Startup") {
                Toggle("Launch at login", isOn: Binding(
                    get: { settings.settings.launchAtStartup },
                    set: { newValue in
                        settings.settings.launchAtStartup = newValue
                        LaunchAtLoginManager.shared.setEnabled(newValue)
                    }
                ))

                Toggle("Show in Dock", isOn: Binding(
                    get: { settings.settings.showInDock },
                    set: { newValue in
                        settings.settings.showInDock = newValue
                        NSApp.setActivationPolicy(newValue ? .regular : .accessory)
                    }
                ))
            }

            Section("Appearance") {
                Picker("Theme", selection: Binding(
                    get: { settings.settings.appearanceMode },
                    set: { settings.settings.appearanceMode = $0 }
                )) {
                    ForEach(AppearanceMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("Refresh") {
                Picker("Auto-refresh interval", selection: Binding(
                    get: { settings.settings.refreshInterval },
                    set: { settings.settings.refreshInterval = $0 }
                )) {
                    Text("5 seconds").tag(5.0 as TimeInterval)
                    Text("10 seconds").tag(10.0 as TimeInterval)
                    Text("30 seconds").tag(30.0 as TimeInterval)
                    Text("1 minute").tag(60.0 as TimeInterval)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Services Settings

struct ServicesSettingsTab: View {
    @ObservedObject private var settings = SettingsManager.shared

    var body: some View {
        Form {
            Section("Visible service types") {
                Toggle("Homebrew services", isOn: Binding(
                    get: { settings.settings.showBrewServices },
                    set: { settings.settings.showBrewServices = $0 }
                ))

                Toggle("Launchd services", isOn: Binding(
                    get: { settings.settings.showLaunchdServices },
                    set: { settings.settings.showLaunchdServices = $0 }
                ))

                Toggle("Include system launchd services", isOn: Binding(
                    get: { settings.settings.showSystemLaunchdServices },
                    set: { settings.settings.showSystemLaunchdServices = $0 }
                ))
                .disabled(!settings.settings.showLaunchdServices)
            }

            Section("Pinned services") {
                if settings.settings.pinnedServiceIds.isEmpty {
                    Text("No pinned services yet. Right-click a service to pin it.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                } else {
                    ForEach(settings.settings.pinnedServiceIds, id: \.self) { id in
                        HStack {
                            Text(id)
                                .font(.system(size: 12))
                            Spacer()
                            Button(action: {
                                settings.settings.pinnedServiceIds.removeAll(where: { $0 == id })
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - About

struct AboutTab: View {
    var body: some View {
        VStack(spacing: 12) {
            Spacer()

            Image(systemName: "server.rack")
                .font(.system(size: 40))
                .foregroundColor(.accentColor)

            Text("DodoServant")
                .font(.system(size: 18, weight: .bold))

            Text("Version \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0")")
                .font(.system(size: 12))
                .foregroundColor(.secondary)

            Text("A lightweight macOS menu bar app to manage\nyour Homebrew and Launchd services.")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Spacer()

            Text("MIT License")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
        .padding()
    }
}
