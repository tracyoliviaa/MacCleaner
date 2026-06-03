import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var viewModel: DashboardViewModel
    let openSection: (SidebarItem) -> Void

    init(openSection: @escaping (SidebarItem) -> Void = { _ in }) {
        self.openSection = openSection
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                PageHeader(title: "Dashboard", subtitle: "Live disk, memory, CPU, and health overview.")

                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 14)
                        Circle()
                            .trim(from: 0, to: viewModel.disk?.usedFraction ?? 0)
                            .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .animation(.easeInOut(duration: 0.6), value: viewModel.disk?.usedFraction)
                        VStack(spacing: 2) {
                            Text("\(Int((viewModel.disk?.usedFraction ?? 0) * 100))%")
                                .font(.title2.bold())
                            Text("Used")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(width: 140, height: 140)

                    Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 16) {
                        GridRow {
                            MetricTile(title: "Disk Free", value: Formatters.fileSize(viewModel.disk?.free ?? 0), symbol: "internaldrive")
                            MetricTile(title: "RAM Used", value: Formatters.fileSize(Int64(viewModel.memory.used)), symbol: "memorychip")
                        }
                        GridRow {
                            MetricTile(title: "CPU Load", value: "\(Int(viewModel.cpuPercent))%", symbol: "cpu")
                            MetricTile(title: "Health Score", value: "\(viewModel.healthScore)/100", symbol: "heart.text.square")
                        }
                    }
                }

                HStack(spacing: 12) {
                    StatusPill(title: "Disk", value: viewModel.diskStatus, symbol: "internaldrive")
                    StatusPill(title: "Memory", value: viewModel.memoryStatus, symbol: "memorychip")
                    StatusPill(title: "Recommendation", value: viewModel.statusMessage, symbol: "sparkles")
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Quick Actions")
                        .font(.title2.bold())

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 210), spacing: 12)], spacing: 12) {
                        DashboardActionButton(title: "Run Smart Scan", subtitle: "One scan for key cleanup areas", symbol: "wand.and.stars") {
                            openSection(.smartScan)
                        }
                        DashboardActionButton(title: "Scan System Junk", subtitle: "Caches, logs, temporary files", symbol: "sparkles") {
                            openSection(.systemJunk)
                        }
                        DashboardActionButton(title: "Find Large Files", subtitle: "Review space-heavy files", symbol: "doc.text.magnifyingglass") {
                            openSection(.largeFiles)
                        }
                        DashboardActionButton(title: "Uninstall Apps", subtitle: "Review apps and leftovers", symbol: "app.badge") {
                            openSection(.appUninstaller)
                        }
                        DashboardActionButton(title: "Check Trash", subtitle: "Review current Trash contents", symbol: "trash") {
                            openSection(.trashCleanup)
                        }
                        DashboardActionButton(title: "Optimize Startup", subtitle: "Review launch agents and daemons", symbol: "power") {
                            openSection(.startupOptimization)
                        }
                        DashboardActionButton(title: "Watch CPU", subtitle: "Top processes by usage", symbol: "cpu") {
                            openSection(.cpuMonitor)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Next Up")
                        .font(.title2.bold())
                    Button("Review Full Disk Access", systemImage: "lock.shield") {
                        openSection(.settings)
                    }
                    .buttonStyle(.bordered)
                    Text("Granting Full Disk Access helps scans see the files macOS otherwise hides from utility apps.")
                        .foregroundStyle(.secondary)
                }
            }
            .padding(28)
        }
        .onAppear { viewModel.start() }
        .onDisappear { viewModel.stop() }
    }
}

private struct StatusPill: View {
    let title: String
    let value: String
    let symbol: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol).foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.caption).foregroundStyle(.secondary)
                Text(value).font(.headline).lineLimit(2).minimumScaleFactor(0.8)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct DashboardActionButton: View {
    let title: String
    let subtitle: String
    let symbol: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.title3)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.headline)
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
    }
}
