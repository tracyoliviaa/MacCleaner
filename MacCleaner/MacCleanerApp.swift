import SwiftUI

@main
struct MacCleanerApp: App {
    @StateObject private var settings = AppSettings()
    @StateObject private var dashboardViewModel = DashboardViewModel()
    @StateObject private var systemJunkViewModel = SystemJunkViewModel()
    @StateObject private var largeFilesViewModel = LargeFilesViewModel()
    @StateObject private var duplicateFinderViewModel = DuplicateFinderViewModel()
    @StateObject private var memoryViewModel = MemoryViewModel()
    @StateObject private var cpuViewModel = CPUViewModel()
    @StateObject private var privacyViewModel = PrivacyViewModel()
    @StateObject private var smartScanViewModel = SmartScanViewModel()
    @StateObject private var startupViewModel = StartupViewModel()
    @StateObject private var appUninstallerViewModel = AppUninstallerViewModel()
    @StateObject private var trashViewModel = TrashViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(settings)
                .environmentObject(dashboardViewModel)
                .environmentObject(systemJunkViewModel)
                .environmentObject(largeFilesViewModel)
                .environmentObject(duplicateFinderViewModel)
                .environmentObject(memoryViewModel)
                .environmentObject(cpuViewModel)
                .environmentObject(privacyViewModel)
                .environmentObject(smartScanViewModel)
                .environmentObject(startupViewModel)
                .environmentObject(appUninstallerViewModel)
                .environmentObject(trashViewModel)
                .frame(minWidth: 980, minHeight: 680)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
    }
}
