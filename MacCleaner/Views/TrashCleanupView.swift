import SwiftUI

struct TrashItemRow: Identifiable, Hashable {
    let id = UUID()
    let file: FileItem
    var isSelected = true
}

struct TrashCleanupView: View {
    @EnvironmentObject private var viewModel: TrashViewModel
    @State private var showDeleteAlert = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            PageHeader(
                title: "Trash Cleanup",
                subtitle: "Review current Trash contents before permanent deletion."
            )

            HStack {
                Button("Scan", systemImage: "magnifyingglass") { viewModel.scan() }
                    .disabled(viewModel.isScanning || viewModel.isDeleting)
                Button("Open Trash", systemImage: "trash") { viewModel.openInFinder() }
                Button("Select All") { viewModel.selectAll(true) }
                    .disabled(viewModel.rows.isEmpty)
                Button("Select None") { viewModel.selectAll(false) }
                    .disabled(viewModel.rows.isEmpty)
                Button("Delete Selected", systemImage: "xmark.bin") { showDeleteAlert = true }
                    .disabled(viewModel.selectedRows.isEmpty || viewModel.isDeleting)
                    .buttonStyle(.borderedProminent)
                if viewModel.isScanning || viewModel.isDeleting {
                    ProgressView().controlSize(.small)
                }
                Spacer()
                Text("Selected: \(Formatters.fileSize(viewModel.selectedSize))")
                    .foregroundStyle(.secondary)
                Text("Total: \(Formatters.fileSize(viewModel.totalSize))")
                    .foregroundStyle(.secondary)
            }

            if viewModel.isDeleting {
                ProgressView(value: viewModel.progress)
            }

            if !viewModel.statusMessage.isEmpty {
                Text(viewModel.statusMessage).foregroundStyle(.secondary)
            }

            if viewModel.rows.isEmpty && !viewModel.isScanning {
                EmptyStateView(text: "Trash is empty or click Scan to check")
            } else {
                Table(viewModel.rows) {
                    TableColumn("Delete") { row in
                        Toggle("", isOn: Binding(
                            get: { row.isSelected },
                            set: { viewModel.setSelected(row, selected: $0) }
                        ))
                        .labelsHidden()
                    }
                    .width(60)
                    TableColumn("Name") { Text($0.file.name) }
                    TableColumn("Size") { Text(Formatters.fileSize($0.file.size)) }.width(120)
                    TableColumn("Modified") { row in
                        Text(row.file.modifiedAt ?? .distantPast, style: .date)
                    }
                    .width(120)
                    TableColumn("Path") { row in
                        Text(row.file.path)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding(28)
        .onAppear {
            if viewModel.rows.isEmpty && !viewModel.isScanning {
                viewModel.scan()
            }
        }
        .alert("Permanently delete selected Trash items?", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete Forever", role: .destructive) { viewModel.deleteSelected() }
        } message: {
            Text("This cannot be undone. \(viewModel.selectedRows.count) item\(viewModel.selectedRows.count == 1 ? "" : "s") will be permanently removed.")
        }
    }
}
