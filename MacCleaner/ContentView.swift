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
        case .dashboard: return "gauge.with.dots.needle.67percent"
        case .smartScan: return "wand.and.stars"
        case .systemJunk: return "sparkles"
        case .trashCleanup: return "trash"
        case .largeFiles: return "doc.text.magnifyingglass"
        case .duplicateFinder: return "doc.on.doc"
        case .appUninstaller: return "app.badge"
        case .startupOptimization: return "power"
        case .memoryCleaner: return "memorychip"
        case .cpuMonitor: return "cpu"
        case .privacyCleaner: return "hand.raised"
        case .settings: return "gearshape"
        }
    }
}

struct ContentView: View {
    @State private var selection: SidebarItem = .dashboard

    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var dashboardVM: DashboardViewModel
    @EnvironmentObject private var systemJunkVM: SystemJunkViewModel
    @EnvironmentObject private var largeFilesVM: LargeFilesViewModel
    @EnvironmentObject private var duplicateVM: DuplicateFinderViewModel
    @EnvironmentObject private var memoryVM: MemoryViewModel
    @EnvironmentObject private var cpuVM: CPUViewModel
    @EnvironmentObject private var privacyVM: PrivacyViewModel
    @EnvironmentObject private var smartScanVM: SmartScanViewModel
    @EnvironmentObject private var startupVM: StartupViewModel
    @EnvironmentObject private var appUninstallerVM: AppUninstallerViewModel
    @EnvironmentObject private var trashVM: TrashViewModel

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
            detailView
        }
    }

    @ViewBuilder
    private var detailView: some View {
        switch selection {
        case .dashboard:
            DashboardView(navigate: { selection = $0 })
                .environmentObject(settings)
                .environmentObject(dashboardVM)
        case .smartScan:
            SmartScanView(navigate: { selection = $0 })
                .environmentObject(settings)
                .environmentObject(smartScanVM)
        case .systemJunk:
            SystemJunkView()
                .environmentObject(settings)
                .environmentObject(systemJunkVM)
        case .trashCleanup:
            TrashCleanupView()
                .environmentObject(trashVM)
        case .largeFiles:
            LargeFilesView()
                .environmentObject(settings)
                .environmentObject(largeFilesVM)
                .environmentObject(smartScanVM)
        case .duplicateFinder:
            DuplicateFinderView()
                .environmentObject(settings)
                .environmentObject(duplicateVM)
        case .appUninstaller:
            AppUninstallerView()
                .environmentObject(settings)
                .environmentObject(appUninstallerVM)
        case .startupOptimization:
            StartupOptimizationView()
                .environmentObject(startupVM)
        case .memoryCleaner:
            MemoryCleanerView()
                .environmentObject(memoryVM)
        case .cpuMonitor:
            CPUMonitorView()
                .environmentObject(cpuVM)
        case .privacyCleaner:
            PrivacyCleanerView()
                .environmentObject(settings)
                .environmentObject(privacyVM)
        case .settings:
            SettingsView()
                .environmentObject(settings)
        }
    }
}
