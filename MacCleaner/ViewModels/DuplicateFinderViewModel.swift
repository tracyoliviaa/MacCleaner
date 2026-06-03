import Foundation
import AppKit

@MainActor
final class DuplicateFinderViewModel: ObservableObject {
    @Published var groups: [DuplicateGroup] = []
    @Published var selectedFolder: URL? = FileManager.default.homeDirectoryForCurrentUser
    @Published var isScanning = false
    @Published var isCleaning = false
    @Published var statusMessage = ""
    @Published var progress = 0.0

    var recoverableSize: Int64 {
        groups.reduce(0) { $0 + $1.recoverableSize }
    }

    var duplicateFileCount: Int {
        groups.reduce(0) { $0 + max(0, $1.files.count - 1) }
    }

    func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK {
            selectedFolder = panel.url
            groups = []
            statusMessage = "Ready to scan \(panel.url?.lastPathComponent ?? "folder")."
        }
    }

    func resetToHomeFolder() {
        selectedFolder = FileManager.default.homeDirectoryForCurrentUser
        groups = []
        statusMessage = "Ready to scan your home folder."
    }

    func scan() {
        guard let selectedFolder else { return }
        isScanning = true
        statusMessage = "Scanning for same-size files, then hashing candidates..."
        Task {
            let result = await HashService.duplicateGroupsResult(in: selectedFolder)
            groups = result.groups
            statusMessage = groups.isEmpty
                ? "No duplicate groups were found. \(result.detailText)"
                : "Found \(groups.count) duplicate group\(groups.count == 1 ? "" : "s"). \(result.detailText)"
            isScanning = false
        }
    }

    func cleanDuplicates(in group: DuplicateGroup, mode: TrashService.CleanupMode) {
        isCleaning = true
        progress = 0
        let filesToTrash = Array(group.files.dropFirst())
        statusMessage = mode == .trash ? "Moving duplicate extras to Trash..." : "Deleting duplicate extras..."
        Task {
            let summary = await TrashService.cleanMany(filesToTrash.map(\.url), mode: mode) { value in
                await MainActor.run { self.progress = value }
            }
            statusMessage = summary.message
            groups.removeAll { $0.id == group.id }
            isCleaning = false
        }
    }

    func cleanAllDuplicateExtras(mode: TrashService.CleanupMode) {
        isCleaning = true
        progress = 0
        let filesToTrash = groups.flatMap { $0.files.dropFirst() }
        statusMessage = mode == .trash ? "Moving all duplicate extras to Trash..." : "Deleting all duplicate extras..."
        Task {
            let summary = await TrashService.cleanMany(filesToTrash.map(\.url), mode: mode) { value in
                await MainActor.run { self.progress = value }
            }
            statusMessage = summary.message
            groups = []
            isCleaning = false
        }
    }

    func reveal(_ file: FileItem) {
        NSWorkspace.shared.activateFileViewerSelecting([file.url])
    }
}
