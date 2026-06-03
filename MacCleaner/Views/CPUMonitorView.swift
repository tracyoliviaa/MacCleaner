import SwiftUI

struct CPUMonitorView: View {
    @StateObject private var viewModel = CPUViewModel()
    @State private var pendingQuit: ProcessItem?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            PageHeader(title: "CPU Monitor", subtitle: "Live top processes by CPU usage.")

            HStack {
                Button("Refresh", systemImage: "arrow.clockwise") { viewModel.refresh() }
                if viewModel.isRefreshing { ProgressView().controlSize(.small) }
                Spacer()
                Text(viewModel.statusMessage)
                    .foregroundStyle(.secondary)
            }

            if viewModel.processes.isEmpty, !viewModel.isRefreshing {
                EmptyStateView(text: "No process data yet")
            } else {
                Table(viewModel.processes) {
                    TableColumn("Process", value: \.name)
                    TableColumn("PID") { Text("\($0.pid)") }.width(80)
                    TableColumn("CPU %") { Text($0.cpuPercent, format: .number.precision(.fractionLength(1))) }.width(90)
                    TableColumn("Memory") { Text("\($0.memoryMB, specifier: "%.1f") MB") }.width(110)
                    TableColumn("") { item in
                        Button("Force Quit", systemImage: "xmark.circle") { pendingQuit = item }
                            .disabled(item.pid == 0 || item.pid == 1)
                    }
                    .width(120)
                }
            }
        }
        .padding(28)
        .onAppear { viewModel.start() }
        .onDisappear { viewModel.stop() }
        .alert("Force quit process?", isPresented: Binding(
            get: { pendingQuit != nil },
            set: { if !$0 { pendingQuit = nil } }
        )) {
            Button("Cancel", role: .cancel) { pendingQuit = nil }
            Button("Force Quit", role: .destructive) {
                if let pendingQuit { viewModel.forceQuit(pendingQuit) }
                pendingQuit = nil
            }
        } message: {
            Text("Force quitting can cause unsaved work to be lost. Avoid force quitting system processes unless you know what they are.")
        }
    }
}
