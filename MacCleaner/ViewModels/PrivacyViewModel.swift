import Foundation

@MainActor
final class PrivacyViewModel: ObservableObject {
    @Published var categories: [JunkCategory] = []
    @Published var isScanning = false
    @Published var isCleaning = false
    @Published var statusMessage = ""

    var selectedSize: Int64 {
        categories.filter(\.isSelected).reduce(0) { $0 + $1.totalSize }
    }

    func scan(exclusions: [String] = []) {
        isScanning = true
        statusMessage = "Scanning browser and recent-item locations..."
        Task {
            let result = await Task.detached { PrivacyService.scan(exclusions: exclusions) }.value
            categories = result.categories
            isScanning = false
            let totalSize = categories.reduce(0) { $0 + $1.totalSize }
            let totalFiles = categories.reduce(0) { $0 + $1.fileCount }
            if categories.isEmpty {
                statusMessage = result.blockedLocationCount > 0
                    ? "No privacy data could be shown. macOS blocked \(result.blockedLocationCount) location\(result.blockedLocationCount == 1 ? "" : "s"); give MacCleaner Full Disk Access, then scan again."
                    : "No supported privacy data was found after checking \(result.checkedLocationCount) location\(result.checkedLocationCount == 1 ? "" : "s"). Close browsers and scan again if you expected results."
            } else {
                let blockedText = result.blockedLocationCount == 0
                    ? ""
                    : " \(result.blockedLocationCount) location\(result.blockedLocationCount == 1 ? "" : "s") were blocked by macOS."
                statusMessage = "Found \(Formatters.fileSize(totalSize)) across \(totalFiles) file\(totalFiles == 1 ? "" : "s") in \(categories.count) categor\(categories.count == 1 ? "y" : "ies").\(blockedText)"
            }
        }
    }

    func setSelected(_ category: JunkCategory, selected: Bool) {
        guard let index = categories.firstIndex(where: { $0.id == category.id }) else { return }
        categories[index].isSelected = selected
    }

    func cleanSelected(mode: TrashService.CleanupMode, exclusions: [String] = []) {
        isCleaning = true
        statusMessage = mode == .trash ? "Moving selected privacy data to Trash..." : "Deleting selected privacy data..."
        Task {
            let urls = categories.filter(\.isSelected).flatMap { PrivacyService.files(for: $0, exclusions: exclusions) }
            let summary = await TrashService.cleanMany(urls, mode: mode) { _ in }
            statusMessage = summary.message
            isCleaning = false
            scan(exclusions: exclusions)
        }
    }
}
