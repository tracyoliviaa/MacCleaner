import Foundation

@MainActor
final class DashboardViewModel: ObservableObject {
    @Published var disk: DiskSnapshot?
    @Published var memory = MemoryService.snapshot()
    @Published var cpuPercent: Double = 0
    @Published var junkSize: Int64 = 0
    @Published var statusMessage = "Live system stats refresh every 3 seconds."

    private var timer: Timer?

    var healthScore: Int {
        let freeDisk = disk.map { $0.total == 0 ? 1 : Double($0.free) / Double($0.total) } ?? 1
        let freeMemory = memory.total == 0 ? 1 : Double(memory.free) / Double(memory.total)
        let junkPenalty = min(25, Int(Double(junkSize) / Double(1024 * 1024 * 1024) * 2))
        return max(0, min(100, Int((freeDisk * 45) + (freeMemory * 35) + 20) - junkPenalty))
    }

    var diskStatus: String {
        guard let disk else { return "Unknown" }
        let freeRatio = disk.total == 0 ? 0 : Double(disk.free) / Double(disk.total)
        if freeRatio < 0.1 { return "Low space" }
        if freeRatio < 0.2 { return "Watch space" }
        return "Healthy"
    }

    var memoryStatus: String {
        memory.pressure
    }

    var recommendedAction: String {
        if diskStatus == "Low space" {
            return "Run Large Files or Trash Cleanup to recover disk space."
        }
        if memory.pressure != "Normal" {
            return "Open Memory Cleaner to inspect current pressure."
        }
        if cpuPercent > 200 {
            return "Open CPU Monitor to review busy processes."
        }
        return "Start with System Junk or Large Files when you want to clean up."
    }

    func start() {
        refresh()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func refresh() {
        disk = try? DiskService.rootDiskSnapshot()
        memory = MemoryService.snapshot()
        Task {
            cpuPercent = (try? CPUService.topProcesses(limit: 15).reduce(0) { $0 + $1.cpuPercent }) ?? 0
            statusMessage = recommendedAction
        }
    }
}
