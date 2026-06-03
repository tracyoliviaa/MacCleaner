import SwiftUI

struct LargeFilesView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var viewModel: LargeFilesViewModel
    @EnvironmentObject private var smartScanViewModel: SmartScanViewModel
    @State private var pendingTrash: FileItem?
    @State private var selectedIDs = Set<UUID>()
    @State private var showBulkTrashAlert = false

    private var selectedFiles: [FileItem] {
        viewModel.files.filter { selectedIDs.contains($0.id) }
    }

    private var selectedSize: Int64 {
        selectedFiles.reduce(0) { $0 + $1.size }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            PageHeader(title: "Large Files", subtitle: "Find big files in your home folder and mounted volumes.")

            FullDiskAccessNotice()

            HStack {
                Button("Scan", systemImage: "magnifyingglass") {
                    viewModel.scan(thresholdMB: settings.largeFileThresholdMB, exclusions: settings.exclusions)
                }
                .disabled(viewModel.isScanning || viewModel.isCleaning)

                Button(settings.moveToTrash ? "Trash Selected" : "Delete Selected", systemImage: settings.moveToTrash ? "trash" : "xmark.bin") { showBulkTrashAlert = true }
                    .disabled(selectedFiles.isEmpty || viewModel.isScanning || viewModel.isCleaning)

                if viewModel.isScanning || viewModel.isCleaning { ProgressView().controlSize(.small) }
                Spacer()
                Text("Selected: \(Formatters.fileSize(selectedSize))")
                    .foregroundStyle(.secondary)
                Text("Total: \(Formatters.fileSize(viewModel.totalSize))")
                    .foregroundStyle(.secondary)
            }

            if viewModel.isCleaning {
                ProgressView(value: viewModel.progress)
            }

            if viewModel.isScanning {
                VStack(alignment: .leading, spacing: 8) {
                    ProgressView()
                    Text("Scanning for files over \(Int(settings.largeFileThresholdMB)) MB. This can take a minute on a full Mac.")
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
            }

            if !viewModel.statusMessage.isEmpty {
                Text(viewModel.statusMessage)
                    .foregroundStyle(.secondary)
            }

            Text("Threshold: \(Int(settings.largeFileThresholdMB)) MB")
                .font(.callout)
                .foregroundStyle(.secondary)

            if viewModel.files.isEmpty, !viewModel.isScanning {
                VStack(spacing: 14) {
                    EmptyStateView(text: smartScanViewModel.result?.largeFiles.isEmpty == false ? "Loading large files from Smart Scan" : "Click Scan to review large files")
                    Text("If Smart Scan found large files, they appear here automatically. The Scan button does a deeper search and can take longer.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(minHeight: 280)
            } else {
                Table(viewModel.files, selection: $selectedIDs) {
                    TableColumn("Name", value: \.name)
                    TableColumn("Path", value: \.path)
                    TableColumn("Size") { Text(Formatters.fileSize($0.size)) }.width(110)
                    TableColumn("Modified") { file in
                        Text(file.modifiedAt ?? .distantPast, style: .date)
                    }
                    .width(120)
                    TableColumn("") { file in
                        HStack {
                            Button("Reveal", systemImage: "finder") { viewModel.reveal(file) }
                            Button(settings.moveToTrash ? "Trash" : "Delete", systemImage: settings.moveToTrash ? "trash" : "xmark.bin") { pendingTrash = file }
                        }
                    }
                    .width(170)
                }
            }
        }
        .padding(28)
        .onAppear {
            viewModel.loadFromSmartScan(smartScanViewModel.result?.largeFiles ?? [])
        }
        .onChange(of: smartScanViewModel.result?.largeFiles ?? []) { _, files in
            viewModel.loadFromSmartScan(files)
        }
        .alert(settings.moveToTrash ? "Move file to Trash?" : "Permanently delete file?", isPresented: Binding(
            get: { pendingTrash != nil },
            set: { if !$0 { pendingTrash = nil } }
        )) {
            Button("Cancel", role: .cancel) { pendingTrash = nil }
            Button(settings.moveToTrash ? "Move to Trash" : "Delete Forever", role: .destructive) {
                if let pendingTrash {
                    viewModel.clean(pendingTrash, mode: settings.moveToTrash ? .trash : .permanent)
                }
                pendingTrash = nil
            }
        }
        .alert(settings.moveToTrash ? "Move selected files to Trash?" : "Permanently delete selected files?", isPresented: $showBulkTrashAlert) {
            Button("Cancel", role: .cancel) {}
            Button(settings.moveToTrash ? "Move to Trash" : "Delete Forever", role: .destructive) {
                viewModel.clean(selectedFiles, mode: settings.moveToTrash ? .trash : .permanent)
                selectedIDs.removeAll()
            }
        } message: {
            Text(settings.moveToTrash ? "MacCleaner will move \(selectedFiles.count) selected file\(selectedFiles.count == 1 ? "" : "s") to Trash." : "This cannot be undone.")
        }
    }
}
