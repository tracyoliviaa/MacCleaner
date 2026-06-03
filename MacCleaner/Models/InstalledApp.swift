import Foundation

struct InstalledApp: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let bundleIdentifier: String
    let url: URL
    let size: Int64
    let leftovers: [FileItem]

    var path: String {
        url.path
    }

    var totalRecoverableSize: Int64 {
        size + leftovers.reduce(0) { $0 + $1.size }
    }
}
