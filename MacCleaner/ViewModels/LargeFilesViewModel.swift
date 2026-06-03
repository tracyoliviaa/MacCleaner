import Foundation
import AppKit

@MainActor
final class LargeFilesViewModel: ObservableObject {
    @Published var files: [FileItem] = []
    @Published var isScanning = false
    @Published var isCleaning = false
    @Published var statusMessage = ""
    @Published var progress = 0.0

    var totalSize: Int64 {
        files.reduce(0) { $0 + $1.size }
    }

    func scan(thresholdMB: Double, exclusions: [String]) {
        isScanning = true
        statusMessage = "Scanning home folder and mounted volumes..."
        let threshold = Int64(thresholdMB * 1024 * 1024)
        Task {
            let result = await DiskService.largeFilesResult(thresholdBytes: threshold, exclusions: exclusions)
            files = result.files
            statusMessage = files.isEmpty
                ? "No files over \(Int(thresholdMB)) MB were found. \(result.skippedText)"
                : "Found \(files.count) file\(files.count == 1 ? "" : "s") over \(Int(thresholdMB)) MB after scanning \(result.scannedCount). \(result.skippedText)"
            isScanning = false
        }
    }

    func reveal(_ file: FileItem) {
        NSWorkspace.shared.activateFileViewerSelecting([file.url])
    }

    func clean(_ file: FileItem, mode: TrashService.CleanupMode) {
        clean([file], mode: mode)
    }

    func clean(_ selectedFiles: [FileItem], mode: TrashService.CleanupMode) {
        isCleaning = true
        progress = 0
        statusMessage = mode == .trash ? "Moving selected files to Trash..." : "Deleting selected files..."
        Task {
            let summary = await TrashService.cleanMany(selectedFiles.map(\.url), mode: mode) { value in
                await MainActor.run { self.progress = value }
            }
            files.removeAll { file in selectedFiles.contains(file) }
            statusMessage = summary.message
            isCleaning = false
        }
    }
}
