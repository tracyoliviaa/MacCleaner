import SwiftUI

struct StartupOptimizationView: View {
    @StateObject private var viewModel = StartupViewModel()
    @State private var pendingDisable: StartupItem?
    @State private var pendingEnable: StartupItem?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            PageHeader(title: "Startup Optimization", subtitle: "Review apps and helpers that launch automatically.")

            FullDiskAccessNotice()

            HStack {
                Button("Scan", systemImage: "magnifyingglass") { viewModel.scan() }
                    .disabled(viewModel.isScanning)
                if viewModel.isScanning { ProgressView().controlSize(.small) }
                Spacer()
                Text("Enabled: \(viewModel.enabledCount)")
                    .foregroundStyle(.secondary)
                Text("Total: \(viewModel.items.count)")
                    .foregroundStyle(.secondary)
            }

            if !viewModel.statusMessage.isEmpty {
                Text(viewModel.statusMessage)
                    .foregroundStyle(.secondary)
            }

            if viewModel.items.isEmpty, !viewModel.isScanning {
                EmptyStateView(text: "No startup items found")
            } else {
                Table(viewModel.items) {
                    TableColumn("Status") { item in
                        Label(item.isEnabled ? "Enabled" : "Disabled", systemImage: item.isEnabled ? "checkmark.circle" : "pause.circle")
                            .foregroundStyle(item.isEnabled ? .primary : .secondary)
                    }
                    .width(110)
                    TableColumn("Name") { item in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.name)
                            Text(item.label)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    TableColumn("Type") { item in Text(item.scope.rawValue) }.width(90)
                    TableColumn("Path", value: \.path)
                    TableColumn("") { item in
                        HStack {
                            Button("Reveal", systemImage: "finder") { viewModel.reveal(item) }
                            if item.canDisable {
                                Button("Disable", systemImage: "pause.circle") { pendingDisable = item }
                            } else if item.canEnable {
                                Button("Enable", systemImage: "play.circle") { pendingEnable = item }
                            }
                        }
                    }
                    .width(190)
                }
            }
        }
        .padding(28)
        .onAppear {
            if viewModel.items.isEmpty {
                viewModel.scan()
            }
        }
        .alert("Disable this startup item?", isPresented: Binding(
            get: { pendingDisable != nil },
            set: { if !$0 { pendingDisable = nil } }
        )) {
            Button("Cancel", role: .cancel) { pendingDisable = nil }
            Button("Disable", role: .destructive) {
                if let pendingDisable { viewModel.disable(pendingDisable) }
                pendingDisable = nil
            }
        } message: {
            Text("MacCleaner will move the startup file to a disabled folder so it can be restored later.")
        }
        .alert("Enable this startup item?", isPresented: Binding(
            get: { pendingEnable != nil },
            set: { if !$0 { pendingEnable = nil } }
        )) {
            Button("Cancel", role: .cancel) { pendingEnable = nil }
            Button("Enable") {
                if let pendingEnable { viewModel.enable(pendingEnable) }
                pendingEnable = nil
            }
        } message: {
            Text("MacCleaner will restore this item to your user LaunchAgents folder.")
        }
    }
}
