import Foundation

enum AppUninstallerService {
    static func scan(exclusions: [String] = []) -> [InstalledApp] {
        appLocations()
            .flatMap { apps(in: $0) }
            .filter { !isExcluded($0.path, exclusions: exclusions) }
            .map { appURL in
                let name = appURL.deletingPathExtension().lastPathComponent
                let bundleIdentifier = Bundle(url: appURL)?.bundleIdentifier ?? normalized(name)
                let leftovers = findLeftovers(appName: name, bundleIdentifier: bundleIdentifier, exclusions: exclusions)
                return InstalledApp(
                    name: name,
                    bundleIdentifier: bundleIdentifier,
                    url: appURL,
                    size: allocatedSize(appURL),
                    leftovers: leftovers
                )
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    static func uninstall(_ app: InstalledApp, includeApp: Bool, includeLeftovers: Bool, mode: TrashService.CleanupMode) async -> CleanupSummary {
        var urls: [URL] = []
        if includeApp { urls.append(app.url) }
        if includeLeftovers { urls.append(contentsOf: app.leftovers.map(\.url)) }
        return await TrashService.cleanMany(urls, mode: mode) { _ in }
    }

    private static func appLocations() -> [URL] {
        [
            URL(fileURLWithPath: "/Applications"),
            FileManager.default.homeDirectoryForCurrentUser.appending(path: "Applications")
        ]
    }

    private static func apps(in folder: URL) -> [URL] {
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: [.isDirectoryKey, .isPackageKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return contents.filter { $0.pathExtension == "app" }
    }

    private static func findLeftovers(appName: String, bundleIdentifier: String, exclusions: [String]) -> [FileItem] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let roots = [
            home.appending(path: "Library/Application Support"),
            home.appending(path: "Library/Caches"),
            home.appending(path: "Library/Preferences"),
            home.appending(path: "Library/Logs"),
            home.appending(path: "Library/LaunchAgents"),
            home.appending(path: "Library/Saved Application State"),
            home.appending(path: "Library/Containers"),
            home.appending(path: "Library/Group Containers")
        ]

        let terms = searchTerms(appName: appName, bundleIdentifier: bundleIdentifier)
        var results: [FileItem] = []
        var seenPaths = Set<String>()

        for root in roots where FileManager.default.fileExists(atPath: root.path) {
            guard let contents = try? FileManager.default.contentsOfDirectory(
                at: root,
                includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey, .fileSizeKey, .totalFileAllocatedSizeKey, .contentModificationDateKey],
                options: [.skipsHiddenFiles]
            ) else {
                continue
            }

            for url in contents where !isExcluded(url.path, exclusions: exclusions) {
                let candidate = url.lastPathComponent.lowercased()
                guard terms.contains(where: { candidate.contains($0) }) else { continue }
                let path = url.standardizedFileURL.path
                guard seenPaths.insert(path).inserted else { continue }
                results.append(FileItem(url: url, size: allocatedSize(url), modifiedAt: modifiedDate(url)))
            }
        }

        return results.sorted { $0.size > $1.size }
    }

    private static func searchTerms(appName: String, bundleIdentifier: String) -> [String] {
        let normalizedName = normalized(appName)
        let bundleParts = bundleIdentifier
            .lowercased()
            .split(separator: ".")
            .map(String.init)
            .filter { $0.count > 2 && !["com", "org", "net", "app"].contains($0) }

        return Array(Set(([normalizedName, bundleIdentifier.lowercased()] + bundleParts).filter { !$0.isEmpty }))
    }

    private static func allocatedSize(_ url: URL) -> Int64 {
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .isDirectoryKey, .fileSizeKey, .totalFileAllocatedSizeKey]
        guard let values = try? url.resourceValues(forKeys: keys) else { return 0 }

        if values.isRegularFile == true {
            return Int64(values.totalFileAllocatedSize ?? values.fileSize ?? 0)
        }

        guard values.isDirectory == true || url.pathExtension == "app" else { return 0 }
        guard let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: Array(keys), options: [.skipsHiddenFiles]) else {
            return 0
        }

        var total: Int64 = 0
        for case let child as URL in enumerator {
            guard let childValues = try? child.resourceValues(forKeys: keys),
                  childValues.isRegularFile == true else { continue }
            total += Int64(childValues.totalFileAllocatedSize ?? childValues.fileSize ?? 0)
        }
        return total
    }

    private static func modifiedDate(_ url: URL) -> Date? {
        (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? nil
    }

    private static func normalized(_ value: String) -> String {
        value.lowercased()
            .replacingOccurrences(of: ".app", with: "")
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "_", with: "")
    }

    private static func isExcluded(_ path: String, exclusions: [String]) -> Bool {
        exclusions.contains { !$0.isEmpty && (path == $0 || path.hasPrefix($0 + "/")) }
    }
}
