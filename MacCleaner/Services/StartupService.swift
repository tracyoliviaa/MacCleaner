import Foundation

enum StartupService {
    private static var disabledRoot: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appending(path: "Library/Application Support/MacCleaner/Disabled Startup Items")
    }

    static func scan() -> [StartupItem] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let locations: [(StartupItem.Scope, URL, Bool)] = [
            (.user, home.appending(path: "Library/LaunchAgents"), true),
            (.system, URL(fileURLWithPath: "/Library/LaunchAgents"), true),
            (.daemon, URL(fileURLWithPath: "/Library/LaunchDaemons"), true),
            (.protectedSystem, URL(fileURLWithPath: "/System/Library/LaunchAgents"), true),
            (.protectedSystem, URL(fileURLWithPath: "/System/Library/LaunchDaemons"), true),
            (.disabled, disabledRoot, false)
        ]

        return locations.flatMap { scope, folder, enabled in
            plistFiles(in: folder).map { url in
                StartupItem(
                    label: label(for: url),
                    url: url,
                    scope: scope,
                    isEnabled: enabled
                )
            }
        }
        .sorted {
            if $0.isEnabled != $1.isEnabled { return $0.isEnabled && !$1.isEnabled }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    static func disable(_ item: StartupItem) throws {
        guard item.isEnabled else { return }
        try FileManager.default.createDirectory(at: disabledRoot, withIntermediateDirectories: true)
        let destination = uniqueDestination(for: item.url.lastPathComponent)
        try FileManager.default.moveItem(at: item.url, to: destination)
    }

    static func enable(_ item: StartupItem) throws {
        guard !item.isEnabled else { return }
        let home = FileManager.default.homeDirectoryForCurrentUser
        let launchAgents = home.appending(path: "Library/LaunchAgents")
        try FileManager.default.createDirectory(at: launchAgents, withIntermediateDirectories: true)
        let destination = launchAgents.appending(path: item.url.lastPathComponent)
        guard !FileManager.default.fileExists(atPath: destination.path) else {
            throw CocoaError(.fileWriteFileExists)
        }
        try FileManager.default.moveItem(at: item.url, to: destination)
    }

    private static func plistFiles(in folder: URL) -> [URL] {
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return contents.filter { url in
            url.pathExtension == "plist"
                && ((try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true)
        }
    }

    private static func label(for url: URL) -> String {
        guard
            let data = try? Data(contentsOf: url),
            let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
            let dictionary = plist as? [String: Any],
            let label = dictionary["Label"] as? String,
            !label.isEmpty
        else {
            return url.deletingPathExtension().lastPathComponent
        }
        return label
    }

    private static func uniqueDestination(for filename: String) -> URL {
        var candidate = disabledRoot.appending(path: filename)
        guard FileManager.default.fileExists(atPath: candidate.path) else { return candidate }

        let base = (filename as NSString).deletingPathExtension
        let ext = (filename as NSString).pathExtension
        var index = 2
        repeat {
            candidate = disabledRoot.appending(path: "\(base)-\(index).\(ext)")
            index += 1
        } while FileManager.default.fileExists(atPath: candidate.path)

        return candidate
    }
}
