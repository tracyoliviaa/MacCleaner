import AppKit
import Foundation

@MainActor
final class AppUninstallerViewModel: ObservableObject {
    @Published var apps: [InstalledApp] = []
    @Published var selectedApp: InstalledApp?
    @Published var isScanning = false
    @Published var isCleaning = false
    @Published var statusMessage = ""

    func scan(exclusions: [String]) {
        isScanning = true
        statusMessage = "Scanning installed apps and related Library files..."
        Task {
            let result = await Task.detached { AppUninstallerService.scan(exclusions: exclusions) }.value
            apps = result
            selectedApp = selectedApp.flatMap { selected in result.first(where: { $0.url == selected.url }) } ?? result.first
            isScanning = false
            statusMessage = result.isEmpty
                ? "No applications were found."
                : "Found \(result.count) app\(result.count == 1 ? "" : "s"). Select one to review before uninstalling."
        }
    }

    func reveal(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    func uninstall(_ app: InstalledApp, includeApp: Bool, includeLeftovers: Bool, mode: TrashService.CleanupMode, exclusions: [String]) {
        isCleaning = true
        statusMessage = mode == .trash ? "Moving selected app data to Trash..." : "Deleting selected app data..."
        Task {
            let summary = await AppUninstallerService.uninstall(app, includeApp: includeApp, includeLeftovers: includeLeftovers, mode: mode)
            statusMessage = summary.message
            isCleaning = false
            scan(exclusions: exclusions)
        }
    }
}
