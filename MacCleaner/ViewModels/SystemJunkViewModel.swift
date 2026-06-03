import Foundation

@MainActor
final class SystemJunkViewModel: ObservableObject {
    @Published var categories: [JunkCategory] = []
    @Published var isScanning = false
    @Published var isCleaning = false
    @Published var progress = 0.0
    @Published var statusMessage = ""

    var selectedSize: Int64 {
        categories.filter(\.isSelected).reduce(0) { $0 + $1.totalSize }
    }

    func scan(exclusions: [String] = []) {
        isScanning = true
        statusMessage = "Scanning common junk locations..."
        Task {
            let results = await DiskService.scanJunk(exclusions: exclusions)
            categories = results
            isScanning = false
            let totalSize = results.reduce(0) { $0 + $1.totalSize }
            let totalFiles = results.reduce(0) { $0 + $1.fileCount }
            statusMessage = results.isEmpty
                ? "No junk locations were available to scan."
                : "Found \(Formatters.fileSize(totalSize)) across \(totalFiles) file\(totalFiles == 1 ? "" : "s") in \(results.count) categor\(results.count == 1 ? "y" : "ies")."
        }
    }

    func setSelected(_ category: JunkCategory, selected: Bool) {
        guard let index = categories.firstIndex(where: { $0.id == category.id }) else { return }
        categories[index].isSelected = selected
    }

    func setAllSelected(_ selected: Bool) {
        for index in categories.indices {
            categories[index].isSelected = selected
        }
    }

    func cleanSelected(mode: TrashService.CleanupMode, exclusions: [String] = []) {
        let selected = categories.filter(\.isSelected)
        isCleaning = true
        progress = 0
        statusMessage = mode == .trash ? "Moving selected items to Trash..." : "Deleting selected items..."
        Task {
            let urls = selected.flatMap { DiskService.filesForJunkCategory($0, exclusions: exclusions) }
            let summary = await TrashService.cleanMany(urls, mode: mode) { value in
                await MainActor.run { self.progress = value }
            }
            statusMessage = summary.message
            isCleaning = false
            scan(exclusions: exclusions)
        }
    }
}
