import SwiftUI
import AppKit

struct TrashItemRow: Identifiable, Hashable {
    let id = UUID()
    let file: FileItem
    var isSelected = true
}

struct TrashCleanupView: View {
    @State private var rows: [TrashItemRow] = []
    @State private var isScanning = false
    @State private var isDeleting = false
    @State private var progress = 0.0
    @State private var statusMessage = ""
    @State private var showDeleteAlert = false

    private var selectedRows: [TrashItemRow] {
        rows.filter(\.isSelected)
    }

    private var selectedSize: Int64 {
        selectedRows.reduce(0) { $0 + $1.file.size }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            PageHeader(title: "Trash Cleanup", subtitle: "Review current Trash contents before permanent deletion.")

            HStack {
                Button("Scan Trash", systemImage: "magnifyingglass") { scan() }
                    .disabled(isScanning || isDeleting)
                Button("Open Trash", systemImage: "trash") {
                    NSWorkspace.shared.open(URL(filePath: "\(NSHomeDirectory())/.Trash"))
                }
                Button("Delete Selected", systemImage: "xmark.bin") { showDeleteAlert = true }
                    .disabled(selectedRows.isEmpty || isDeleting)
                Spacer()
                Text("Selected: \(Formatters.fileSize(selectedSize))").foregroundStyle(.secondary)
            }

            if isScanning || isDeleting {
                ProgressView(value: isDeleting ? progress : nil)
            }

            if !statusMessage.isEmpty {
                Text(statusMessage).foregroundStyle(.secondary)
            }

            if rows.isEmpty, !isScanning {
                EmptyStateView(text: "Trash is empty")
            } else {
                Table(rows) {
                    TableColumn("Delete") { row in
                        Toggle("", isOn: Binding(
                            get: { row.isSelected },
                            set: { setSelected(row, selected: $0) }
                        ))
                        .labelsHidden()
                    }
                    .width(70)
                    TableColumn("Name") { Text($0.file.name) }
                    TableColumn("Path") { Text($0.file.path).foregroundStyle(.secondary) }
                    TableColumn("Size") { Text(Formatters.fileSize($0.file.size)) }.width(120)
                    TableColumn("Modified") { row in
                        Text(row.file.modifiedAt ?? .distantPast, style: .date)
                    }
                    .width(120)
                }
            }
        }
        .padding(28)
        .onAppear {
            if rows.isEmpty && !isScanning {
                scan()
            }
        }
        .alert("Permanently delete selected Trash items?", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete Forever", role: .destructive) { deleteSelected() }
        } message: {
            Text("This cannot be undone. Files already in Trash will be removed permanently.")
        }
    }

    private func scan() {
        isScanning = true
        statusMessage = "Scanning Trash..."
        Task {
            let items = await DiskService.trashItems()
            rows = items.map { TrashItemRow(file: $0) }
            statusMessage = items.isEmpty ? "Trash is empty." : "Found \(items.count) item\(items.count == 1 ? "" : "s") in Trash."
            isScanning = false
        }
    }

    private func setSelected(_ row: TrashItemRow, selected: Bool) {
        guard let index = rows.firstIndex(where: { $0.id == row.id }) else { return }
        rows[index].isSelected = selected
    }

    private func deleteSelected() {
        let urls = selectedRows.map { $0.file.url }
        isDeleting = true
        progress = 0
        statusMessage = "Deleting selected Trash items..."
        Task {
            let summary = await TrashService.permanentlyDeleteMany(urls) { value in
                await MainActor.run { progress = value }
            }
            statusMessage = summary.message
            isDeleting = false
            scan()
        }
    }
}
