import SwiftUI

struct LargeFilesView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var viewModel: LargeFilesViewModel
    @EnvironmentObject private var smartScanVM: SmartScanViewModel
    @State private var pendingTrash: FileItem?
    @State private var selectedIDs = Set<UUID>()
    @State private var showBulkAlert = false

    private var selectedFiles: [FileItem] {
        viewModel.files.filter { selectedIDs.contains($0.id) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            PageHeader(
                title: "Large Files",
                subtitle: "Find big files in your home folder and mounted volumes."
            )

            FullDiskAccessNotice()

            HStack {
                Button("Scan", systemImage: "magnifyingglass") {
                    selectedIDs.removeAll()
                    viewModel.scan(thresholdMB: settings.largeFileThresholdMB, exclusions: settings.exclusions)
                }
                .disabled(viewModel.isScanning || viewModel.isCleaning)

                Button(settings.moveToTrash ? "Trash Selected" : "Delete Selected",
                       systemImage: settings.moveToTrash ? "trash" : "xmark.bin") {
                    showBulkAlert = true
                }
                .disabled(selectedFiles.isEmpty || viewModel.isScanning || viewModel.isCleaning)

                if viewModel.isScanning || viewModel.isCleaning {
                    ProgressView().controlSize(.small)
                }
                Spacer()
                Text("Threshold: \(Int(settings.largeFileThresholdMB)) MB")
                    .foregroundStyle(.secondary)
                Text("Total: \(Formatters.fileSize(viewModel.totalSize))")
                    .foregroundStyle(.secondary)
                Text("Selected: \(Formatters.fileSize(selectedFiles.reduce(0) { $0 + $1.size }))")
                    .foregroundStyle(.secondary)
            }

            if viewModel.isScanning {
                VStack(alignment: .leading, spacing: 6) {
                    ProgressView()
                    Text("Scanning for files over \(Int(settings.largeFileThresholdMB)) MB...")
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
            }

            if viewModel.isCleaning {
                ProgressView(value: viewModel.progress)
            }

            if !viewModel.statusMessage.isEmpty {
                Text(viewModel.statusMessage).foregroundStyle(.secondary)
            }

            if viewModel.files.isEmpty && !viewModel.isScanning {
                EmptyStateView(text: "Click Scan to find large files")
            } else {
                Table(viewModel.files, selection: $selectedIDs) {
                    TableColumn("Name", value: \.name)
                    TableColumn("Size") { Text(Formatters.fileSize($0.size)) }.width(110)
                    TableColumn("Modified") { file in
                        Text(file.modifiedAt ?? .distantPast, style: .date)
                    }
                    .width(120)
                    TableColumn("Path") { file in
                        Text(file.path)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    TableColumn("") { file in
                        HStack {
                            Button("Reveal", systemImage: "finder") { viewModel.reveal(file) }
                            Button(settings.moveToTrash ? "Trash" : "Delete",
                                   systemImage: settings.moveToTrash ? "trash" : "xmark.bin") {
                                pendingTrash = file
                            }
                        }
                    }
                    .width(170)
                }
            }
        }
        .padding(28)
        .onAppear {
            if viewModel.files.isEmpty && !viewModel.isScanning {
                if let smartFiles = smartScanVM.result?.largeFiles, !smartFiles.isEmpty {
                    viewModel.loadFromSmartScan(smartFiles)
                } else {
                    viewModel.scan(thresholdMB: settings.largeFileThresholdMB, exclusions: settings.exclusions)
                }
            }
        }
        .alert(settings.moveToTrash ? "Move file to Trash?" : "Delete file?",
               isPresented: Binding(get: { pendingTrash != nil }, set: { if !$0 { pendingTrash = nil } })) {
            Button("Cancel", role: .cancel) { pendingTrash = nil }
            Button(settings.moveToTrash ? "Move to Trash" : "Delete Forever", role: .destructive) {
                if let f = pendingTrash { viewModel.clean(f, mode: settings.moveToTrash ? .trash : .permanent) }
                pendingTrash = nil
            }
        }
        .alert(settings.moveToTrash ? "Move selected files to Trash?" : "Delete selected files?",
               isPresented: $showBulkAlert) {
            Button("Cancel", role: .cancel) {}
            Button(settings.moveToTrash ? "Move to Trash" : "Delete Forever", role: .destructive) {
                viewModel.clean(selectedFiles, mode: settings.moveToTrash ? .trash : .permanent)
                selectedIDs.removeAll()
            }
        } message: {
            Text("\(selectedFiles.count) file\(selectedFiles.count == 1 ? "" : "s") selected.")
        }
    }
}
