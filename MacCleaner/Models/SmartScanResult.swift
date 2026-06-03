import Foundation

struct SmartScanResult: Codable {
    let junkCategories: [JunkCategory]
    let trashItems: [FileItem]
    let largeFiles: [FileItem]
    let duplicateGroups: [DuplicateGroup]
    let startupItems: [StartupItem]
    let privacyCategories: [JunkCategory]

    var junkSize: Int64 {
        junkCategories.reduce(0) { $0 + $1.totalSize }
    }

    var trashSize: Int64 {
        trashItems.reduce(0) { $0 + $1.size }
    }

    var largeFilesSize: Int64 {
        largeFiles.reduce(0) { $0 + $1.size }
    }

    var duplicatesSize: Int64 {
        duplicateGroups.reduce(0) { $0 + $1.recoverableSize }
    }

    var privacySize: Int64 {
        privacyCategories.reduce(0) { $0 + $1.totalSize }
    }

    var totalRecoverableSize: Int64 {
        junkSize + trashSize + duplicatesSize + privacySize
    }
}

struct SmartScanAction: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let detail: String
    let size: Int64
    let count: Int
    let destination: SidebarItem
    let symbol: String
}
