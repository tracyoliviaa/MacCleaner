import Foundation

@MainActor
final class MemoryViewModel: ObservableObject {
    @Published var snapshot = MemoryService.snapshot()
    @Published var isPurging = false
    @Published var statusMessage = "Memory stats refresh every 3 seconds."
    private var timer: Timer?

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

    func refresh() {
        snapshot = MemoryService.snapshot()
    }

    func purge() {
        isPurging = true
        statusMessage = "Attempting memory purge..."
        Task {
            let result = await MemoryService.purgeInactiveMemory()
            refresh()
            statusMessage = result.message
            isPurging = false
        }
    }
}
