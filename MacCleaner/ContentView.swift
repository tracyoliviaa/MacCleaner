import SwiftUI

enum SidebarItem: String, CaseIterable, Identifiable {
    case dashboard = "Dashboard"
    case smartScan = "Smart Scan"
    case systemJunk = "System Junk"
    case trashCleanup = "Trash Cleanup"
    case largeFiles = "Large Files"
    case duplicateFinder = "Duplicate Finder"
    case appUninstaller = "App Uninstaller"
    case startupOptimization = "Startup Optimization"
    case memoryCleaner = "Memory Cleaner"
    case cpuMonitor = "CPU Monitor"
    case privacyCleaner = "Privacy Cleaner"
    case settings = "Settings"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .dashboard: "gauge.with.dots.needle.67percent"
        case .smartScan: "wand.and.stars"
        case .systemJunk: "sparkles"
        case .trashCleanup: "trash"
        case .largeFiles: "doc.text.magnifyingglass"
        case .duplicateFinder: "doc.on.doc"
        case .appUninstaller: "app.badge"
        case .startupOptimization: "power"
        case .memoryCleaner: "memorychip"
        case .cpuMonitor: "cpu"
        case .privacyCleaner: "hand.raised"
        case .settings: "gearshape"
        }
    }
}

struct ContentView: View {
    @State private var selection: SidebarItem = .dashboard

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                ForEach(SidebarItem.allCases) { item in
                    Label(item.rawValue, systemImage: item.symbol)
                        .tag(item)
                }
            }
            .navigationTitle("MacCleaner")
        } detail: {
            VStack(spacing: 0) {
                AppNavigationBar(selection: selection) { item in
                    selection = item
                }

                Divider()

                detailView
            }
        }
    }

    @ViewBuilder
    private var detailView: some View {
        switch selection {
        case .dashboard: DashboardView { selection = $0 }
        case .smartScan: SmartScanView { selection = $0 }
        case .systemJunk: SystemJunkView()
        case .trashCleanup: TrashCleanupView()
        case .largeFiles: LargeFilesView()
        case .duplicateFinder: DuplicateFinderView()
        case .appUninstaller: AppUninstallerView()
        case .startupOptimization: StartupOptimizationView()
        case .memoryCleaner: MemoryCleanerView()
        case .cpuMonitor: CPUMonitorView()
        case .privacyCleaner: PrivacyCleanerView()
        case .settings: SettingsView()
        }
    }
}

private struct AppNavigationBar: View {
    let selection: SidebarItem
    let open: (SidebarItem) -> Void

    var body: some View {
        HStack(spacing: 10) {
            NavigationBarButton(title: "Dashboard", symbol: "house", isActive: selection == .dashboard) {
                open(.dashboard)
            }

            NavigationBarButton(title: "Smart Scan", symbol: "wand.and.stars", isActive: selection == .smartScan) {
                open(.smartScan)
            }

            Spacer()

            Label(selection.rawValue, systemImage: selection.symbol)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(.bar)
    }
}

private struct NavigationBarButton: View {
    let title: String
    let symbol: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        if isActive {
            Button(title, systemImage: symbol, action: action)
                .buttonStyle(.borderedProminent)
        } else {
            Button(title, systemImage: symbol, action: action)
                .buttonStyle(.bordered)
        }
    }
}
