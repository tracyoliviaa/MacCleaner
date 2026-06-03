import Foundation

@MainActor
final class TrashViewModel: ObservableObject {
    @Published var rows: [TrashItemRow] = []
    @Published var isScanning = false
    @Published var isDeleting = false
    @Published var progress = 0.0
    @Published var statusMessage = ""

    var selectedRows: [TrashItemRow] {
        rows.filter(\.isSelected)
    }

    var selectedSize: Int64 {
        selectedRows.reduce(0) { $0 + $1.file.size }
    }

    func scan() {
        isScanning = true
        statusMessage = "Scanning Trash..."
        Task {
            let items = await DiskService.trashItems()
            rows = items.map { TrashItemRow(file: $0) }
            statusMessage = items.isEmpty ? "Trash is empty." : "Found \(items.count) item\(items.count == 1 ? "" : "s") in Trash."
            isScanning = false
        }
    }

    func setSelected(_ row: TrashItemRow, selected: Bool) {
        guard let index = rows.firstIndex(where: { $0.id == row.id }) else { return }
        rows[index].isSelected = selected
    }

    func deleteSelected() {
        let urls = selectedRows.map { $0.file.url }
        isDeleting = true
        progress = 0
        statusMessage = "Deleting selected Trash items..."
        Task {
            let summary = await TrashService.permanentlyDeleteMany(urls) { value in
                await MainActor.run { self.progress = value }
            }
            statusMessage = summary.message
            isDeleting = false
            scan()
        }
    }
}
