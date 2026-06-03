import SwiftUI
import AppKit

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
            PageHeader(title: "Trash Cleanup", subtitle: "Review current Trash contents before permanent deletion.")

            HStack {
                Button("Scan Trash", systemImage: "magnifyingglass") { viewModel.scan() }
                    .disabled(viewModel.isScanning || viewModel.isDeleting)
                Button("Open Trash", systemImage: "trash") {
                    NSWorkspace.shared.open(URL(filePath: "\(NSHomeDirectory())/.Trash"))
                }
                Button("Delete Selected", systemImage: "xmark.bin") { showDeleteAlert = true }
                    .disabled(viewModel.selectedRows.isEmpty || viewModel.isDeleting)
                Spacer()
                Text("Selected: \(Formatters.fileSize(viewModel.selectedSize))").foregroundStyle(.secondary)
            }

            if viewModel.isScanning || viewModel.isDeleting {
                ProgressView(value: viewModel.isDeleting ? viewModel.progress : nil)
            }

            if !viewModel.statusMessage.isEmpty {
                Text(viewModel.statusMessage).foregroundStyle(.secondary)
            }

            if viewModel.rows.isEmpty, !viewModel.isScanning {
                EmptyStateView(text: "Trash is empty")
            } else {
                Table(viewModel.rows) {
                    TableColumn("Delete") { row in
                        Toggle("", isOn: Binding(
                            get: { row.isSelected },
                            set: { viewModel.setSelected(row, selected: $0) }
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
            if viewModel.rows.isEmpty && !viewModel.isScanning {
                viewModel.scan()
            }
        }
        .alert("Permanently delete selected Trash items?", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete Forever", role: .destructive) { viewModel.deleteSelected() }
        } message: {
            Text("This cannot be undone. Files already in Trash will be removed permanently.")
        }
    }
}
