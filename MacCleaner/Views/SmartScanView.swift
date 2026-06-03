import SwiftUI

struct SmartScanView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var viewModel: SmartScanViewModel
    let openSection: (SidebarItem) -> Void
    @State private var showSafeCleanupAlert = false

    init(openSection: @escaping (SidebarItem) -> Void = { _ in }) {
        self.openSection = openSection
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                PageHeader(title: "Smart Scan", subtitle: "One scan for cleanup, privacy, storage, duplicates, and startup review.")

                FullDiskAccessNotice()

                HStack(spacing: 14) {
                    Button("Run Smart Scan", systemImage: "play.circle") {
                        viewModel.scan(
                            largeFileThresholdMB: settings.largeFileThresholdMB,
                            exclusions: settings.exclusions
                        )
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.isScanning || viewModel.isFixing)

                    Button(settings.moveToTrash ? "Move Safe Items to Trash" : "Delete Safe Items", systemImage: settings.moveToTrash ? "trash" : "xmark.bin") {
                        showSafeCleanupAlert = true
                    }
                    .disabled(viewModel.safeCleanupSize == 0 || viewModel.isScanning || viewModel.isFixing)

                    if viewModel.isScanning || viewModel.isFixing { ProgressView().controlSize(.small) }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Found to Review")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(Formatters.fileSize(viewModel.totalFoundSize))
                            .font(.title3.bold())
                    }
                }

                Text(viewModel.statusMessage)
                    .foregroundStyle(.secondary)

                if viewModel.isScanning || viewModel.isFixing {
                    VStack(alignment: .leading, spacing: 8) {
                        ProgressView(value: viewModel.progress)
                        Text(viewModel.currentStep)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    .padding(12)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                }

                if viewModel.safeCleanupSize > 0 {
                    Text("\(Formatters.fileSize(viewModel.safeCleanupSize)) can be moved to Trash now: system junk and privacy cleanup only. Large files, duplicates, startup items, and existing Trash stay review-only.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                if viewModel.actions.isEmpty, !viewModel.isScanning, !viewModel.isFixing {
                    EmptyStateView(text: "Run Smart Scan to review your Mac")
                        .frame(minHeight: 220)
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 12)], spacing: 12) {
                        ForEach(viewModel.actions) { action in
                            SmartScanActionCard(action: action) {
                                openSection(action.destination)
                            }
                        }
                    }
                }
            }
            .padding(28)
        }
        .alert(settings.moveToTrash ? "Move safe items to Trash?" : "Delete safe items?", isPresented: $showSafeCleanupAlert) {
            Button("Cancel", role: .cancel) {}
            Button(settings.moveToTrash ? "Move to Trash" : "Delete Forever", role: .destructive) {
                viewModel.fixSafeCleanup(
                    mode: settings.moveToTrash ? .trash : .permanent,
                    largeFileThresholdMB: settings.largeFileThresholdMB,
                    exclusions: settings.exclusions
                )
            }
        } message: {
            Text(viewModel.safeCleanupPreview)
        }
    }
}

private struct SmartScanActionCard: View {
    let action: SmartScanAction
    let open: () -> Void

    var body: some View {
        Button(action: open) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: action.symbol)
                        .font(.title2)
                        .foregroundStyle(.tint)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(action.title)
                    .font(.headline)
                Text(action.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                HStack {
                    Text(action.size > 0 ? Formatters.fileSize(action.size) : action.count > 0 ? "\(action.count) item\(action.count == 1 ? "" : "s")" : "Open")
                        .font(.title3.bold())
                    Spacer()
                    Text("Review")
                        .foregroundStyle(.secondary)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 150, alignment: .leading)
        }
        .buttonStyle(.plain)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
    }
}
