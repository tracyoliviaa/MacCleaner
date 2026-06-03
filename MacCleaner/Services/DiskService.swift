import Darwin
import Foundation

struct DiskSnapshot {
    let total: Int64
    let free: Int64
    var used: Int64 { max(0, total - free) }
    var usedFraction: Double { total == 0 ? 0 : Double(used) / Double(total) }
}

enum DiskService {
    static let protectedPrefixes = ["/System", "/usr", "/bin", "/sbin", "/private/var/db"]

    private struct JunkScanTarget {
        let name: String
        let detail: String
        let roots: [URL]
    }

    static func rootDiskSnapshot() throws -> DiskSnapshot {
        let attrs = try FileManager.default.attributesOfFileSystem(forPath: "/")
        let total = attrs[.systemSize] as? Int64 ?? 0
        let free = attrs[.systemFreeSize] as? Int64 ?? 0
        return DiskSnapshot(total: total, free: free)
    }

    static func systemJunkRoots() -> [(String, URL)] {
        junkScanTargets().flatMap { target in target.roots.map { (target.name, $0) } }
    }

    private static func junkScanTargets() -> [JunkScanTarget] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return [
            JunkScanTarget(
                name: "User Caches",
                detail: "App caches in your user Library.",
                roots: [home.appending(path: "Library/Caches")]
            ),
            JunkScanTarget(
                name: "User Logs",
                detail: "Diagnostic logs in your user Library.",
                roots: [home.appending(path: "Library/Logs")]
            ),
            JunkScanTarget(
                name: "Saved Application State",
                detail: "Window restoration state saved by apps.",
                roots: [home.appending(path: "Library/Saved Application State")]
            ),
            JunkScanTarget(
                name: "Container Caches",
                detail: "Caches inside sandboxed app containers.",
                roots: containerCacheRoots(home: home)
            ),
            JunkScanTarget(
                name: "Group Container Caches",
                detail: "Caches shared by app groups.",
                roots: groupContainerCacheRoots(home: home)
            ),
            JunkScanTarget(
                name: "System Caches",
                detail: "Non-SIP cache files in /Library/Caches.",
                roots: [URL(filePath: "/Library/Caches")]
            ),
            JunkScanTarget(
                name: "Temporary Folders",
                detail: "User temporary files under /private/var/folders.",
                roots: temporaryFolderRoots()
            )
        ]
    }

    static func scanJunk(exclusions: [String] = []) async -> [JunkCategory] {
        await withTaskGroup(of: JunkCategory?.self) { group in
            for target in junkScanTargets() {
                group.addTask {
                    let existingRoots = target.roots.filter { FileManager.default.fileExists(atPath: $0.path) }
                    guard let primaryRoot = existingRoots.first else { return nil }
                    let summaries = existingRoots.map { folderSummary(root: $0, cacheOnly: false, exclusions: exclusions) }
                    let fileCount = summaries.reduce(0) { $0 + $1.count }
                    let totalSize = summaries.reduce(Int64(0)) { $0 + $1.size }
                    return JunkCategory(name: target.name, root: primaryRoot, detail: target.detail, fileCount: fileCount, totalSize: totalSize)
                }
            }

            var categories: [JunkCategory] = []
            for await category in group {
                if let category { categories.append(category) }
            }
            return categories.sorted { $0.name < $1.name }
        }
    }

    static func filesForJunkCategory(_ category: JunkCategory, exclusions: [String] = []) -> [URL] {
        let roots = junkScanTargets()
            .first { $0.name == category.name }?
            .roots
            .filter { FileManager.default.fileExists(atPath: $0.path) } ?? [category.root]
        return roots.flatMap { collectFiles(root: $0, exclusions: exclusions).files.map(\.url) }
    }

    static func largeFiles(thresholdBytes: Int64, exclusions: [String]) async -> [FileItem] {
        await largeFilesResult(thresholdBytes: thresholdBytes, exclusions: exclusions).files
    }

    static func largeFilesResult(thresholdBytes: Int64, exclusions: [String]) async -> FileScanResult {
        await Task.detached(priority: .userInitiated) {
            let roots = [FileManager.default.homeDirectoryForCurrentUser] + mountedVolumes()
            let results = roots.map { root in
                collectFiles(root: root, thresholdBytes: thresholdBytes, exclusions: exclusions)
            }
            let files = results.flatMap(\.files).sorted { $0.size > $1.size }
            return FileScanResult(
                files: files,
                scannedCount: results.reduce(0) { $0 + $1.scannedCount },
                skippedCount: results.reduce(0) { $0 + $1.skippedCount }
            )
        }.value
    }

    static func smartScanLargeFilesResult(thresholdBytes: Int64, exclusions: [String]) async -> FileScanResult {
        await Task.detached(priority: .utility) {
            let home = FileManager.default.homeDirectoryForCurrentUser
            let roots = [
                home.appending(path: "Downloads"),
                home.appending(path: "Desktop"),
                home.appending(path: "Documents"),
                home.appending(path: "Movies")
            ].filter { FileManager.default.fileExists(atPath: $0.path) }
            let results = roots.map { root in
                collectFiles(root: root, thresholdBytes: thresholdBytes, exclusions: exclusions)
            }
            let files = results.flatMap(\.files).sorted { $0.size > $1.size }
            return FileScanResult(
                files: files,
                scannedCount: results.reduce(0) { $0 + $1.scannedCount },
                skippedCount: results.reduce(0) { $0 + $1.skippedCount }
            )
        }.value
    }

    static func trashItems() async -> [FileItem] {
        await Task.detached(priority: .utility) {
            trashRoots().flatMap { root in
                collectTrashItems(root: root)
            }
            .sorted { $0.size > $1.size }
        }
        .value
    }

    static func trashRoots() -> [URL] {
        let homeTrash = FileManager.default.homeDirectoryForCurrentUser.appending(path: ".Trash")
        let userID = String(getuid())
        let volumeTrashes = mountedVolumes().flatMap { volume -> [URL] in
            [
                volume.appending(path: ".Trashes").appending(path: userID),
                volume.appending(path: ".Trash")
            ]
        }
        return ([homeTrash] + volumeTrashes).filter { FileManager.default.fileExists(atPath: $0.path) }
    }

    private static func mountedVolumes() -> [URL] {
        let keys: [URLResourceKey] = [.volumeIsBrowsableKey]
        return (try? FileManager.default.contentsOfDirectory(at: URL(filePath: "/Volumes"), includingPropertiesForKeys: keys)) ?? []
    }

    private static func containerCacheRoots(home: URL) -> [URL] {
        let containers = home.appending(path: "Library/Containers")
        guard let appContainers = try? FileManager.default.contentsOfDirectory(at: containers, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) else {
            return []
        }
        return appContainers.map { $0.appending(path: "Data/Library/Caches") }
    }

    private static func groupContainerCacheRoots(home: URL) -> [URL] {
        let containers = home.appending(path: "Library/Group Containers")
        guard let appContainers = try? FileManager.default.contentsOfDirectory(at: containers, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) else {
            return []
        }
        return appContainers.map { $0.appending(path: "Library/Caches") }
    }

    private static func temporaryFolderRoots() -> [URL] {
        let root = URL(filePath: "/private/var/folders")
        guard let firstLevel = try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) else {
            return [root]
        }
        return firstLevel.flatMap { parent in
            ((try? FileManager.default.contentsOfDirectory(at: parent, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])) ?? [])
                .map { $0.appending(path: "T") }
        }
    }

    private static func folderSummary(root: URL, cacheOnly: Bool, exclusions: [String]) -> (count: Int, size: Int64) {
        collectFiles(root: root, cacheOnly: cacheOnly, exclusions: exclusions).files.reduce((0, Int64(0))) { ($0.0 + 1, $0.1 + $1.size) }
    }

    private static func collectTrashItems(root: URL) -> [FileItem] {
        let keys: [URLResourceKey] = [.isRegularFileKey, .isDirectoryKey, .fileSizeKey, .totalFileAllocatedSizeKey, .contentModificationDateKey]
        guard let urls = try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: keys, options: []) else {
            return []
        }

        return urls.map { url in
            let values = try? url.resourceValues(forKeys: Set(keys))
            let size = Int64(values?.totalFileAllocatedSize ?? values?.fileSize ?? folderAllocatedSize(url))
            return FileItem(url: url, size: size, modifiedAt: values?.contentModificationDate)
        }
    }

    private static func folderAllocatedSize(_ root: URL) -> Int {
        let keys: [URLResourceKey] = [.isRegularFileKey, .totalFileAllocatedSizeKey, .fileSizeKey]
        guard let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: keys) else { return 0 }

        var total = 0
        for case let url as URL in enumerator {
            guard let values = try? url.resourceValues(forKeys: Set(keys)),
                  values.isRegularFile == true else { continue }
            total += values.totalFileAllocatedSize ?? values.fileSize ?? 0
        }
        return total
    }

    private static func collectFiles(root: URL, cacheOnly: Bool = false, thresholdBytes: Int64 = 0, exclusions: [String] = []) -> FileScanResult {
        guard !isProtected(root.path), !isExcluded(root.path, exclusions: exclusions) else {
            return FileScanResult(files: [], scannedCount: 0, skippedCount: 1)
        }
        let keys: [URLResourceKey] = [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey, .isDirectoryKey]
        let options: FileManager.DirectoryEnumerationOptions = [.skipsHiddenFiles, .skipsPackageDescendants]
        guard let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: keys, options: options) else {
            return FileScanResult(files: [], scannedCount: 0, skippedCount: 1)
        }

        var files: [FileItem] = []
        var scannedCount = 0
        var skippedCount = 0
        for case let url as URL in enumerator {
            guard !Task.isCancelled else { break }

            if isProtected(url.path) || isExcluded(url.path, exclusions: exclusions) {
                skippedCount += 1
                enumerator.skipDescendants()
                continue
            }

            if cacheOnly, url.hasDirectoryPath, !url.path.contains("/Caches") {
                continue
            }

            guard let values = try? url.resourceValues(forKeys: Set(keys)),
                  values.isRegularFile == true else {
                if url.hasDirectoryPath == false { skippedCount += 1 }
                continue
            }

            scannedCount += 1
            let size = Int64(values.fileSize ?? 0)
            guard size >= thresholdBytes else { continue }
            files.append(FileItem(url: url, size: size, modifiedAt: values.contentModificationDate))
        }
        return FileScanResult(files: files, scannedCount: scannedCount, skippedCount: skippedCount)
    }

    private static func isProtected(_ path: String) -> Bool {
        protectedPrefixes.contains { path == $0 || path.hasPrefix($0 + "/") }
    }

    private static func isExcluded(_ path: String, exclusions: [String]) -> Bool {
        exclusions.contains { !($0.isEmpty) && (path == $0 || path.hasPrefix($0 + "/")) }
    }
}
