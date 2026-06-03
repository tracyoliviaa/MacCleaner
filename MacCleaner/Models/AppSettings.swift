import Foundation

@MainActor
final class AppSettings: ObservableObject {
    @Published var moveToTrash: Bool {
        didSet { UserDefaults.standard.set(moveToTrash, forKey: Keys.moveToTrash) }
    }

    @Published var largeFileThresholdMB: Double {
        didSet { UserDefaults.standard.set(largeFileThresholdMB, forKey: Keys.largeFileThresholdMB) }
    }

    @Published var autoScanOnLaunch: Bool {
        didSet { UserDefaults.standard.set(autoScanOnLaunch, forKey: Keys.autoScanOnLaunch) }
    }

    @Published var exclusions: [String] {
        didSet { UserDefaults.standard.set(exclusions, forKey: Keys.exclusions) }
    }

    init() {
        moveToTrash = UserDefaults.standard.object(forKey: Keys.moveToTrash) as? Bool ?? true
        largeFileThresholdMB = UserDefaults.standard.object(forKey: Keys.largeFileThresholdMB) as? Double ?? 50
        autoScanOnLaunch = UserDefaults.standard.object(forKey: Keys.autoScanOnLaunch) as? Bool ?? false
        exclusions = UserDefaults.standard.stringArray(forKey: Keys.exclusions) ?? []
    }

    func addExclusion(_ path: String) {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !exclusions.contains(trimmed) else { return }
        exclusions.append(trimmed)
    }

    private enum Keys {
        static let moveToTrash = "moveToTrash"
        static let largeFileThresholdMB = "largeFileThresholdMB"
        static let autoScanOnLaunch = "autoScanOnLaunch"
        static let exclusions = "exclusions"
    }
}
