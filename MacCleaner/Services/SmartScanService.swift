import Foundation

enum SmartScanService {
    static func scan(largeFileThresholdMB: Double, exclusions: [String]) async -> SmartScanResult {
        async let junk = DiskService.scanJunk(exclusions: exclusions)
        async let trash = DiskService.trashItems()
        async let large = DiskService.largeFilesResult(
            thresholdBytes: Int64(largeFileThresholdMB * 1024 * 1024),
            exclusions: exclusions
        )
        async let startup = Task.detached { StartupService.scan() }.value
        async let privacy = Task.detached { PrivacyService.categories(exclusions: exclusions) }.value

        return await SmartScanResult(
            junkCategories: junk,
            trashItems: trash,
            largeFiles: large.files,
            duplicateGroups: [],
            startupItems: startup,
            privacyCategories: privacy
        )
    }
}
