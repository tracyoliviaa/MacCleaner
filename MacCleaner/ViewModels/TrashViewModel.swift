import Foundation
import AppKit

@MainActor
final class TrashViewModel: ObservableObject {
    @Published var rows: [TrashItemRow] = []
    @Published var isScanning = false
    @Published var isDeleting = false
    @Published var progress = 0.0
    @Published var statusMessage = ""

    var selectedRows: [TrashItemRow] { rows.filter(\.isSelected) }
    var selectedSize: Int64 { selectedRows.reduce(0) { $0 + $1.file.size } }
    var totalSize: Int64 { rows.reduce(0) { $0 + $1.file.size } }

    func scan() {
        guard !isScanning else { return }
        isScanning = true
        statusMessage = "Scanning Trash..."
        Task {
            let items = await DiskService.trashItems()
            rows = items.map { TrashItemRow(file: $0) }
            isScanning = false
            statusMessage = items.isEmpty
                ? "Trash is empty."
                : "Found \(items.count) item\(items.count == 1 ? "" : "s") - \(Formatters.fileSize(totalSize)) total."
        }
    }

    func setSelected(_ row: TrashItemRow, selected: Bool) {
        guard let i = rows.firstIndex(where: { $0.id == row.id }) else { return }
        rows[i].isSelected = selected
    }

    func selectAll(_ selected: Bool) {
        for i in rows.indices { rows[i].isSelected = selected }
    }

    func deleteSelected() {
        let urls = selectedRows.map(\.file.url)
        guard !urls.isEmpty else { return }
        isDeleting = true
        progress = 0
        statusMessage = "Permanently deleting \(urls.count) item\(urls.count == 1 ? "" : "s")..."
        Task {
            let summary = await TrashService.permanentlyDeleteMany(urls) { value in
                await MainActor.run { self.progress = value }
            }
            statusMessage = summary.message
            isDeleting = false
            scan()
        }
    }

    func openInFinder() {
        let trash = FileManager.default.homeDirectoryForCurrentUser.appending(path: ".Trash")
        NSWorkspace.shared.open(trash)
    }
}
