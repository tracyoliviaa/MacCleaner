import SwiftUI

struct AppUninstallerView: View {
    @EnvironmentObject private var settings: AppSettings
    @StateObject private var viewModel = AppUninstallerViewModel()
    @State private var includeApp = true
    @State private var includeLeftovers = true
    @State private var showUninstallAlert = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            PageHeader(title: "Application Uninstaller", subtitle: "Find apps and review related support files before removing them.")

            FullDiskAccessNotice()

            HStack {
                Button("Scan", systemImage: "magnifyingglass") {
                    viewModel.scan(exclusions: settings.exclusions)
                }
                .disabled(viewModel.isScanning || viewModel.isCleaning)

                if viewModel.isScanning || viewModel.isCleaning { ProgressView().controlSize(.small) }
                Spacer()
                Text("Apps: \(viewModel.apps.count)")
                    .foregroundStyle(.secondary)
            }

            if !viewModel.statusMessage.isEmpty {
                Text(viewModel.statusMessage)
                    .foregroundStyle(.secondary)
            }

            if viewModel.apps.isEmpty, !viewModel.isScanning {
                EmptyStateView(text: "Click Scan to find installed apps")
            } else {
                HSplitView {
                    Table(viewModel.apps, selection: Binding(
                        get: { viewModel.selectedApp?.id },
                        set: { id in viewModel.selectedApp = viewModel.apps.first(where: { $0.id == id }) }
                    )) {
                        TableColumn("App") { app in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(app.name)
                                Text(app.bundleIdentifier)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        TableColumn("Size") { Text(Formatters.fileSize($0.size)) }.width(110)
                        TableColumn("Leftovers") { Text("\($0.leftovers.count)") }.width(90)
                    }
                    .frame(minWidth: 360)

                    detailPane
                        .frame(minWidth: 420)
                }
            }
        }
        .padding(28)
        .onAppear {
            if viewModel.apps.isEmpty {
                viewModel.scan(exclusions: settings.exclusions)
            }
        }
        .alert(settings.moveToTrash ? "Move selected app data to Trash?" : "Permanently delete selected app data?", isPresented: $showUninstallAlert) {
            Button("Cancel", role: .cancel) {}
            Button(settings.moveToTrash ? "Move to Trash" : "Delete Forever", role: .destructive) {
                if let app = viewModel.selectedApp {
                    viewModel.uninstall(
                        app,
                        includeApp: includeApp,
                        includeLeftovers: includeLeftovers,
                        mode: settings.moveToTrash ? .trash : .permanent,
                        exclusions: settings.exclusions
                    )
                }
            }
        } message: {
            Text(settings.moveToTrash ? "Review the selected app and related files before continuing." : "This cannot be undone.")
        }
    }

    @ViewBuilder
    private var detailPane: some View {
        if let app = viewModel.selectedApp {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(app.name)
                            .font(.title2.bold())
                        Text(app.path)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    Spacer()
                    Button("Reveal", systemImage: "finder") { viewModel.reveal(app.url) }
                }

                HStack(spacing: 18) {
                    Toggle("App", isOn: $includeApp)
                    Toggle("Leftovers", isOn: $includeLeftovers)
                    Spacer()
                    Text("Total: \(Formatters.fileSize(totalSelectedSize(app)))")
                        .foregroundStyle(.secondary)
                }

                Button(settings.moveToTrash ? "Uninstall to Trash" : "Delete Selected", systemImage: settings.moveToTrash ? "trash" : "xmark.bin") {
                    showUninstallAlert = true
                }
                .disabled(totalSelectedSize(app) == 0 || viewModel.isScanning || viewModel.isCleaning)
                .buttonStyle(.borderedProminent)

                Divider()

                Text("Related Files")
                    .font(.headline)

                if app.leftovers.isEmpty {
                    Text("No related Library files were found for this app.")
                        .foregroundStyle(.secondary)
                } else {
                    Table(app.leftovers) {
                        TableColumn("Name", value: \.name)
                        TableColumn("Size") { Text(Formatters.fileSize($0.size)) }.width(100)
                        TableColumn("") { file in
                            Button("Reveal", systemImage: "finder") { viewModel.reveal(file.url) }
                        }
                        .width(90)
                    }
                }
            }
            .padding(.leading, 18)
        } else {
            EmptyStateView(text: "Select an app to review")
        }
    }

    private func totalSelectedSize(_ app: InstalledApp) -> Int64 {
        (includeApp ? app.size : 0) + (includeLeftovers ? app.leftovers.reduce(0) { $0 + $1.size } : 0)
    }
}
