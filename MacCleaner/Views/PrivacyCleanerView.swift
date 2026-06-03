import SwiftUI

struct PrivacyCleanerView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var viewModel: PrivacyViewModel
    @State private var showCleanAlert = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            PageHeader(title: "Privacy Cleaner", subtitle: "Review browser and recent-item data before moving it to Trash.")

            FullDiskAccessNotice()

            HStack {
                Button("Scan", systemImage: "magnifyingglass") { viewModel.scan(exclusions: settings.exclusions) }
                Button(settings.moveToTrash ? "Clean" : "Delete", systemImage: settings.moveToTrash ? "trash" : "xmark.bin") { showCleanAlert = true }
                    .disabled(viewModel.selectedSize == 0)
                if viewModel.isScanning || viewModel.isCleaning { ProgressView().controlSize(.small) }
                Spacer()
                Text("Selected: \(Formatters.fileSize(viewModel.selectedSize))").foregroundStyle(.secondary)
            }

            if !viewModel.statusMessage.isEmpty {
                Text(viewModel.statusMessage)
                    .foregroundStyle(.secondary)
            }

            if viewModel.categories.isEmpty, !viewModel.isScanning {
                EmptyStateView(text: "Click Scan to review privacy data")
                    .frame(minHeight: 280)
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
        .alert(settings.moveToTrash ? "Move selected privacy data to Trash?" : "Permanently delete selected privacy data?", isPresented: $showCleanAlert) {
            Button("Cancel", role: .cancel) {}
            Button(settings.moveToTrash ? "Move to Trash" : "Delete Forever", role: .destructive) {
                viewModel.cleanSelected(mode: settings.moveToTrash ? .trash : .permanent, exclusions: settings.exclusions)
            }
        } message: {
            Text(settings.moveToTrash ? "Close browsers before cleaning. Browser data may be recreated when apps reopen." : "This cannot be undone. Close browsers before cleaning.")
        }
    }
}
