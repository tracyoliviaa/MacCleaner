import SwiftUI

struct SystemJunkView: View {
    @EnvironmentObject private var settings: AppSettings
    @StateObject private var viewModel = SystemJunkViewModel()
    @State private var showCleanAlert = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            PageHeader(title: "System Junk", subtitle: "Scan caches, logs, temporary folders, and saved app state.")

            FullDiskAccessNotice()

            HStack {
                Button("Scan", systemImage: "magnifyingglass") { viewModel.scan(exclusions: settings.exclusions) }
                Button("Select All", systemImage: "checkmark.circle") { viewModel.setAllSelected(true) }
                    .disabled(viewModel.categories.isEmpty)
                Button("Select None", systemImage: "circle") { viewModel.setAllSelected(false) }
                    .disabled(viewModel.categories.isEmpty)
                Button(settings.moveToTrash ? "Move Selected to Trash" : "Delete Selected", systemImage: settings.moveToTrash ? "trash" : "xmark.bin") { showCleanAlert = true }
                    .disabled(viewModel.selectedSize == 0)
                    .buttonStyle(.borderedProminent)
                Spacer()
                Text("Selected: \(Formatters.fileSize(viewModel.selectedSize))").foregroundStyle(.secondary)
            }

            if viewModel.isScanning || viewModel.isCleaning {
                ProgressView(value: viewModel.isCleaning ? viewModel.progress : nil)
            }

            if !viewModel.statusMessage.isEmpty {
                Text(viewModel.statusMessage)
                    .foregroundStyle(.secondary)
            }

            if viewModel.categories.isEmpty, !viewModel.isScanning {
                EmptyStateView(text: "No system junk found")
            } else {
                Table(viewModel.categories) {
                    TableColumn("Clean") { category in
                        Toggle("", isOn: Binding(
                            get: { category.isSelected },
                            set: { viewModel.setSelected(category, selected: $0) }
                        ))
                        .labelsHidden()
                    }
                    .width(60)
                    TableColumn("Category") { category in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(category.name)
                            if !category.detail.isEmpty {
                                Text(category.detail)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    TableColumn("Files") { Text("\($0.fileCount)") }.width(80)
                    TableColumn("Size") { Text(Formatters.fileSize($0.totalSize)) }.width(120)
                }
            }
        }
        .padding(28)
        .onAppear {
            if viewModel.categories.isEmpty && !viewModel.isScanning {
                viewModel.scan(exclusions: settings.exclusions)
            }
        }
        .alert(settings.moveToTrash ? "Move selected junk to Trash?" : "Permanently delete selected junk?", isPresented: $showCleanAlert) {
            Button("Cancel", role: .cancel) {}
            Button(settings.moveToTrash ? "Move to Trash" : "Delete Forever", role: .destructive) {
                viewModel.cleanSelected(mode: settings.moveToTrash ? .trash : .permanent, exclusions: settings.exclusions)
            }
        } message: {
            Text(settings.moveToTrash ? "MacCleaner will move selected files to the Trash so you can recover them if needed." : "This cannot be undone. Excluded paths will be skipped.")
        }
    }
}
