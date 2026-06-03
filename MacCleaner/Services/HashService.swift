import CryptoKit
import Foundation

enum HashService {
    static let maxHashableSize: Int64 = 500 * 1024 * 1024

    static func duplicateGroups(in root: URL) async -> [DuplicateGroup] {
        await duplicateGroupsResult(in: root).groups
    }

    static func duplicateGroupsResult(in root: URL) async -> DuplicateScanResult {
        let groupedResult = filesGroupedBySize(root: root)
        let candidates = groupedResult.groups
            .filter { $0.value.count > 1 }

        var groups: [DuplicateGroup] = []
        var hashedCount = 0
        var skippedLargeCount = 0
        var skippedUnreadableCount = groupedResult.skippedUnreadableCount

        for (_, files) in candidates {
            var byHash: [String: [FileItem]] = [:]
            for file in files {
                guard !Task.isCancelled else { break }
                guard file.size <= maxHashableSize else {
                    skippedLargeCount += 1
                    continue
                }
                guard let hash = try? sha256Hash(of: file.url) else {
                    skippedUnreadableCount += 1
                    continue
                }
                hashedCount += 1
                byHash[hash, default: []].append(file)
            }
            groups += byHash
                .filter { $0.value.count > 1 }
                .map { DuplicateGroup(hash: $0.key, files: $0.value.sorted { $0.path < $1.path }) }
        }
        return DuplicateScanResult(
            groups: groups.sorted { $0.recoverableSize > $1.recoverableSize },
            scannedCount: groupedResult.scannedCount,
            hashedCount: hashedCount,
            skippedLargeCount: skippedLargeCount,
            skippedUnreadableCount: skippedUnreadableCount
        )
    }

    private static func filesGroupedBySize(root: URL) -> (groups: [Int64: [FileItem]], scannedCount: Int, skippedUnreadableCount: Int) {
        let keys: [URLResourceKey] = [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey]
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return ([:], 0, 1) }

        var groups: [Int64: [FileItem]] = [:]
        var scannedCount = 0
        var skippedUnreadableCount = 0
        for case let url as URL in enumerator {
            guard !Task.isCancelled else { break }
            guard let values = try? url.resourceValues(forKeys: Set(keys)),
                  values.isRegularFile == true else {
                if url.hasDirectoryPath == false { skippedUnreadableCount += 1 }
                continue
            }
            scannedCount += 1
            let size = Int64(values.fileSize ?? 0)
            guard size > 0 else { continue }
            groups[size, default: []].append(FileItem(url: url, size: size, modifiedAt: values.contentModificationDate))
        }
        return (groups, scannedCount, skippedUnreadableCount)
    }

    private static func sha256Hash(of url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }

        var hasher = SHA256()
        while autoreleasepool(invoking: {
            let data = handle.readData(ofLength: 1024 * 1024)
            guard !data.isEmpty else { return false }
            hasher.update(data: data)
            return true
        }) {}

        let digest = hasher.finalize()
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
