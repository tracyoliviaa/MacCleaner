import Foundation

@MainActor
final class CPUViewModel: ObservableObject {
    @Published var processes: [ProcessItem] = []
    @Published var isRefreshing = false
    @Published var statusMessage = "Process list refreshes every 2 seconds."
    private var timer: Timer?

    func start() {
        refresh()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func refresh() {
        isRefreshing = true
        Task {
            do {
                processes = try CPUService.topProcesses()
                statusMessage = processes.isEmpty ? "No processes were returned." : "Showing top \(processes.count) processes by CPU."
            } catch {
                processes = []
                statusMessage = "Could not read process list."
            }
            isRefreshing = false
        }
    }

    func forceQuit(_ item: ProcessItem) {
        let succeeded = CPUService.forceQuit(pid: item.pid)
        statusMessage = succeeded ? "Force quit requested for \(item.name)." : "Could not force quit \(item.name). It may be a system process or already stopped."
        refresh()
    }
}
