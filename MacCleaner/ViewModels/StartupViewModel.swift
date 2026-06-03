import AppKit
import Foundation

@MainActor
final class StartupViewModel: ObservableObject {
    @Published var items: [StartupItem] = []
    @Published var isScanning = false
    @Published var statusMessage = ""

    var enabledCount: Int {
        items.filter(\.isEnabled).count
    }

    func scan() {
        isScanning = true
        statusMessage = "Scanning startup locations..."
        Task {
            let result = await Task.detached { StartupService.scan() }.value
            items = result
            isScanning = false
            statusMessage = result.isEmpty
                ? "No startup items were found."
                : "Found \(result.count) startup item\(result.count == 1 ? "" : "s"), \(enabledCount) enabled."
        }
    }

    func reveal(_ item: StartupItem) {
        NSWorkspace.shared.activateFileViewerSelecting([item.url])
    }

    func disable(_ item: StartupItem) {
        do {
            try StartupService.disable(item)
            statusMessage = "Disabled \(item.name). Restart or sign out for every app to notice the change."
            scan()
        } catch {
            statusMessage = "Could not disable \(item.name). It may need administrator permission."
        }
    }

    func enable(_ item: StartupItem) {
        do {
            try StartupService.enable(item)
            statusMessage = "Enabled \(item.name)."
            scan()
        } catch {
            statusMessage = "Could not enable \(item.name). A matching item may already exist."
        }
    }
}
