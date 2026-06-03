import SwiftUI

struct MemoryCleanerView: View {
    @StateObject private var viewModel = MemoryViewModel()
    @State private var showPurgeAlert = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            PageHeader(title: "Memory Cleaner", subtitle: "Inspect memory pressure and purge inactive memory.")

            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 16) {
                GridRow {
                    MetricTile(title: "Pressure", value: viewModel.snapshot.pressure, symbol: "waveform.path.ecg")
                    MetricTile(title: "Used", value: "\(Int(viewModel.snapshot.usedFraction * 100))%", symbol: "chart.pie")
                    MetricTile(title: "Free", value: Formatters.fileSize(Int64(viewModel.snapshot.free)), symbol: "checkmark.circle")
                }
                GridRow {
                    MetricTile(title: "Active", value: Formatters.fileSize(Int64(viewModel.snapshot.active)), symbol: "bolt")
                    MetricTile(title: "Inactive", value: Formatters.fileSize(Int64(viewModel.snapshot.inactive)), symbol: "pause.circle")
                    MetricTile(title: "Wired", value: Formatters.fileSize(Int64(viewModel.snapshot.wired)), symbol: "lock")
                }
            }

            Button("Free Up RAM", systemImage: "memorychip") { showPurgeAlert = true }
                .disabled(viewModel.isPurging)

            Text(viewModel.statusMessage)
                .foregroundStyle(.secondary)

            if viewModel.isPurging {
                ProgressView("Waiting for purge to finish")
            }

            Spacer()
        }
        .padding(28)
        .onAppear { viewModel.start() }
        .onDisappear { viewModel.stop() }
        .alert("Run memory purge?", isPresented: $showPurgeAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Run Purge") { viewModel.purge() }
        } message: {
            Text("macOS may block this without administrator permission. This is optional; normal macOS memory management is usually enough.")
        }
    }
}
