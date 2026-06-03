import Foundation

struct FileItem: Identifiable, Hashable, Codable {
    var id = UUID()
    let url: URL
    let size: Int64
    let modifiedAt: Date?

    var name: String { url.lastPathComponent }
    var path: String { url.path }
}

struct JunkCategory: Identifiable, Hashable, Codable {
    var id = UUID()
    let name: String
    let root: URL
    var detail: String = ""
    var fileCount: Int
    var totalSize: Int64
    var isSelected: Bool = true
}

struct DuplicateGroup: Identifiable, Hashable, Codable {
    var id = UUID()
    let hash: String
    let files: [FileItem]

    var recoverableSize: Int64 {
        max(0, files.dropFirst().reduce(Int64(0)) { $0 + $1.size })
    }
}

struct CleanupSummary {
    let attempted: Int
    let succeeded: Int
    let failed: Int

    var message: String {
        if attempted == 0 {
            return "Nothing to clean."
        }
        if failed == 0 {
            return "Cleaned \(succeeded) item\(succeeded == 1 ? "" : "s")."
        }
        return "Cleaned \(succeeded) of \(attempted) items. \(failed) failed."
    }
}

struct FileScanResult {
    let files: [FileItem]
    let scannedCount: Int
    let skippedCount: Int

    var skippedText: String {
        skippedCount == 0 ? "No skipped paths." : "Skipped \(skippedCount) restricted or excluded path\(skippedCount == 1 ? "" : "s")."
    }
}

struct DuplicateScanResult {
    let groups: [DuplicateGroup]
    let scannedCount: Int
    let hashedCount: Int
    let skippedLargeCount: Int
    let skippedUnreadableCount: Int

    var detailText: String {
        "Scanned \(scannedCount) files, hashed \(hashedCount), skipped \(skippedLargeCount) over 500 MB and \(skippedUnreadableCount) unreadable."
    }
}
