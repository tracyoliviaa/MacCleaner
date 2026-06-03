import Foundation

enum TrashService {
    enum CleanupMode {
        case trash
        case permanent

        var actionName: String {
            switch self {
            case .trash: "Moved to Trash"
            case .permanent: "Deleted"
            }
        }
    }

    static func trash(_ url: URL) throws {
        var resultURL: NSURL?
        try FileManager.default.trashItem(at: url, resultingItemURL: &resultURL)
    }

    static func cleanMany(_ urls: [URL], mode: CleanupMode, progress: @Sendable (Double) async -> Void) async -> CleanupSummary {
        switch mode {
        case .trash:
            await trashMany(urls, progress: progress)
        case .permanent:
            await permanentlyDeleteMany(urls, progress: progress)
        }
    }

    static func trashMany(_ urls: [URL], progress: @Sendable (Double) async -> Void) async -> CleanupSummary {
        let total = max(urls.count, 1)
        var succeeded = 0
        for (index, url) in urls.enumerated() {
            guard !Task.isCancelled else { break }
            do {
                try trash(url)
                succeeded += 1
            } catch {
                continue
            }
            await progress(Double(index + 1) / Double(total))
        }
        return CleanupSummary(attempted: urls.count, succeeded: succeeded, failed: urls.count - succeeded)
    }

    static func permanentlyDeleteMany(_ urls: [URL], progress: @Sendable (Double) async -> Void) async -> CleanupSummary {
        let total = max(urls.count, 1)
        var succeeded = 0
        for (index, url) in urls.enumerated() {
            guard !Task.isCancelled else { break }
            do {
                try FileManager.default.removeItem(at: url)
                succeeded += 1
            } catch {
                continue
            }
            await progress(Double(index + 1) / Double(total))
        }
        return CleanupSummary(attempted: urls.count, succeeded: succeeded, failed: urls.count - succeeded)
    }
}
