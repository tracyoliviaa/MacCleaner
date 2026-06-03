import SwiftUI

@main
struct MacCleanerApp: App {
    @StateObject private var settings = AppSettings()
    @StateObject private var dashboardVM = DashboardViewModel()
    @StateObject private var systemJunkVM = SystemJunkViewModel()
    @StateObject private var largeFilesVM = LargeFilesViewModel()
    @StateObject private var duplicateVM = DuplicateFinderViewModel()
    @StateObject private var memoryVM = MemoryViewModel()
    @StateObject private var cpuVM = CPUViewModel()
    @StateObject private var privacyVM = PrivacyViewModel()
    @StateObject private var smartScanVM = SmartScanViewModel()
    @StateObject private var startupVM = StartupViewModel()
    @StateObject private var appUninstallerVM = AppUninstallerViewModel()
    @StateObject private var trashVM = TrashViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(settings)
                .environmentObject(dashboardVM)
                .environmentObject(systemJunkVM)
                .environmentObject(largeFilesVM)
                .environmentObject(duplicateVM)
                .environmentObject(memoryVM)
                .environmentObject(cpuVM)
                .environmentObject(privacyVM)
                .environmentObject(smartScanVM)
                .environmentObject(startupVM)
                .environmentObject(appUninstallerVM)
                .environmentObject(trashVM)
                .frame(minWidth: 980, minHeight: 680)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
    }
}
