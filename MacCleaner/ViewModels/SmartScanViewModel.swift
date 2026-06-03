import Foundation

@MainActor
final class SmartScanViewModel: ObservableObject {
    @Published var result: SmartScanResult?
    @Published var actions: [SmartScanAction] = []
    @Published var isScanning = false
    @Published var isFixing = false
    @Published var progress = 0.0
    @Published var currentStep = ""
    @Published var statusMessage = "Run one scan for cleanup, privacy, storage, duplicates, and startup items."

    init() {
        if let savedResult = Self.loadSavedResult() {
            result = savedResult
            actions = makeActions(from: savedResult)
            statusMessage = "Showing your last Smart Scan result. Run Smart Scan again when you want a fresh check."
        }
    }

    var totalRecoverableSize: Int64 {
        result?.totalRecoverableSize ?? 0
    }

    var totalFoundSize: Int64 {
        guard let result else { return 0 }
        return result.junkSize + result.trashSize + result.largeFilesSize + result.privacySize
    }

    var safeCleanupSize: Int64 {
        (result?.junkSize ?? 0) + (result?.privacySize ?? 0)
    }

    var safeCleanupPreview: String {
        guard let result else { return "Nothing is ready to move." }

        var lines: [String] = []

        for category in result.junkCategories where category.totalSize > 0 {
            lines.append("\(category.name): \(Formatters.fileSize(category.totalSize))")
        }

        for category in result.privacyCategories where category.totalSize > 0 {
            lines.append("\(category.name): \(Formatters.fileSize(category.totalSize))")
        }

        if lines.isEmpty {
            return "Nothing is ready to move."
        }

        return """
        MacCleaner will move only these safe cleanup items to Trash:

        \(lines.prefix(8).joined(separator: "\n"))
        \(lines.count > 8 ? "\n...and \(lines.count - 8) more categories." : "")

        Large files, duplicate files, startup items, and existing Trash stay untouched until you review them yourself.
        """
    }

    func scan(largeFileThresholdMB: Double, exclusions: [String]) {
        isScanning = true
        progress = 0
        currentStep = "Preparing scan"
        statusMessage = "Smart Scan is running. Your previous result stays visible until the fresh result is ready."

        Task {
            currentStep = "Scanning system junk"
            let junk = await DiskService.scanJunk(exclusions: exclusions)
            progress = 0.2

            currentStep = "Checking Trash"
            let trash = await DiskService.trashItems()
            progress = 0.4

            currentStep = "Finding large files"
            let large = await DiskService.smartScanLargeFilesResult(
                thresholdBytes: Int64(largeFileThresholdMB * 1024 * 1024),
                exclusions: exclusions
            )
            progress = 0.65

            currentStep = "Checking privacy data"
            let privacy = await Task.detached { PrivacyService.categories(exclusions: exclusions) }.value
            progress = 0.82

            currentStep = "Checking startup items"
            let startup = await Task.detached { StartupService.scan() }.value
            progress = 1

            let scanResult = SmartScanResult(
                junkCategories: junk,
                trashItems: trash,
                largeFiles: large.files,
                duplicateGroups: [],
                startupItems: startup,
                privacyCategories: privacy
            )
            result = scanResult
            actions = makeActions(from: scanResult)
            Self.save(scanResult)
            isScanning = false
            currentStep = ""
            statusMessage = actions.isEmpty
                ? "Smart Scan finished. No review items were found."
                : "Smart Scan finished. Your results will stay here while you check other pages."
        }
    }

    func fixSafeCleanup(mode: TrashService.CleanupMode, largeFileThresholdMB: Double, exclusions: [String]) {
        guard let result, safeCleanupSize > 0 else { return }

        isFixing = true
        progress = 0
        currentStep = mode == .trash ? "Moving safe cleanup items to Trash" : "Deleting safe cleanup items"
        statusMessage = "Fixing safe cleanup items. Large files, Trash, duplicates, and startup items still need review."

        Task {
            let junkURLs = result.junkCategories.flatMap {
                DiskService.filesForJunkCategory($0, exclusions: exclusions)
            }
            progress = 0.35

            let privacyURLs = result.privacyCategories.flatMap {
                PrivacyService.files(for: $0, exclusions: exclusions)
            }
            progress = 0.55

            let summary = await TrashService.cleanMany(junkURLs + privacyURLs, mode: mode) { value in
                await MainActor.run {
                    self.progress = 0.55 + (value * 0.4)
                }
            }
            progress = 1
            isFixing = false
            currentStep = ""
            statusMessage = "\(summary.message) Running a fresh Smart Scan..."
            scan(largeFileThresholdMB: largeFileThresholdMB, exclusions: exclusions)
        }
    }

    private func makeActions(from result: SmartScanResult) -> [SmartScanAction] {
        var output: [SmartScanAction] = []

        if !result.junkCategories.isEmpty {
            output.append(SmartScanAction(
                title: "Clean System Junk",
                detail: "\(result.junkCategories.count) categor\(result.junkCategories.count == 1 ? "y" : "ies") of caches, logs, and temporary files",
                size: result.junkSize,
                count: result.junkCategories.reduce(0) { $0 + $1.fileCount },
                destination: .systemJunk,
                symbol: "sparkles"
            ))
        }

        if !result.trashItems.isEmpty {
            output.append(SmartScanAction(
                title: "Empty Trash",
                detail: "\(result.trashItems.count) item\(result.trashItems.count == 1 ? "" : "s") currently in Trash",
                size: result.trashSize,
                count: result.trashItems.count,
                destination: .trashCleanup,
                symbol: "trash"
            ))
        }

        if !result.largeFiles.isEmpty {
            output.append(SmartScanAction(
                title: "Review Large Files",
                detail: "\(result.largeFiles.count) file\(result.largeFiles.count == 1 ? "" : "s") over your threshold",
                size: result.largeFilesSize,
                count: result.largeFiles.count,
                destination: .largeFiles,
                symbol: "doc.text.magnifyingglass"
            ))
        }

        if !result.privacyCategories.isEmpty {
            output.append(SmartScanAction(
                title: "Clean Privacy Data",
                detail: "\(result.privacyCategories.count) browser or recent-item categor\(result.privacyCategories.count == 1 ? "y" : "ies")",
                size: result.privacySize,
                count: result.privacyCategories.reduce(0) { $0 + $1.fileCount },
                destination: .privacyCleaner,
                symbol: "hand.raised"
            ))
        }

        let enabledStartupItems = result.startupItems.filter { $0.isEnabled && $0.scope != .protectedSystem }
        if !enabledStartupItems.isEmpty {
            output.append(SmartScanAction(
                title: "Optimize Startup",
                detail: "\(enabledStartupItems.count) manageable startup item\(enabledStartupItems.count == 1 ? "" : "s") enabled",
                size: 0,
                count: enabledStartupItems.count,
                destination: .startupOptimization,
                symbol: "power"
            ))
        }

        output.append(SmartScanAction(
            title: "Run Duplicate Finder",
            detail: "Hash scanning can take longer, so it runs on its own page",
            size: 0,
            count: 0,
            destination: .duplicateFinder,
            symbol: "doc.on.doc"
        ))

        return output
    }

    private static var savedResultURL: URL? {
        guard let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        let folder = support.appending(path: "MacCleaner")
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appending(path: "LastSmartScan.json")
    }

    private static func loadSavedResult() -> SmartScanResult? {
        guard let url = savedResultURL,
              let data = try? Data(contentsOf: url) else {
            return nil
        }
        return try? JSONDecoder().decode(SmartScanResult.self, from: data)
    }

    private static func save(_ result: SmartScanResult) {
        guard let url = savedResultURL,
              let data = try? JSONEncoder().encode(result) else {
            return
        }
        try? data.write(to: url, options: [.atomic])
    }
}
