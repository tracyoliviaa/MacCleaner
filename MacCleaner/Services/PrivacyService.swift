import Foundation

enum PrivacyService {
    struct PrivacyScanResult {
        let categories: [JunkCategory]
        let checkedLocationCount: Int
        let blockedLocationCount: Int
    }

    private struct PrivacyTarget {
        let name: String
        let detail: String
        let root: URL
        let files: [URL]
        let folders: [URL]
    }

    static func categories(exclusions: [String] = []) -> [JunkCategory] {
        scan(exclusions: exclusions).categories
    }

    static func scan(exclusions: [String] = []) -> PrivacyScanResult {
        var blockedLocationCount = 0
        let targets = targets()

        let categories: [JunkCategory] = targets.compactMap { target in
            let result = files(for: target, exclusions: exclusions)
            blockedLocationCount += result.blockedLocationCount
            let files = result.files
            guard !files.isEmpty else { return nil }

            let totalSize = files.reduce(Int64(0)) { total, url in
                let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
                return total + Int64(size)
            }

            return JunkCategory(
                name: target.name,
                root: target.root,
                detail: target.detail,
                fileCount: files.count,
                totalSize: totalSize
            )
        }

        let checkedLocationCount = targets.reduce(0) { $0 + $1.files.count + $1.folders.count }
        return PrivacyScanResult(
            categories: categories,
            checkedLocationCount: checkedLocationCount,
            blockedLocationCount: blockedLocationCount
        )
    }

    static func files(for category: JunkCategory, exclusions: [String] = []) -> [URL] {
        guard let target = targets().first(where: { $0.name == category.name }) else { return [] }
        return files(for: target, exclusions: exclusions).files
    }

    private static func targets() -> [PrivacyTarget] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let safari = home.appending(path: "Library/Safari")
        let safariContainer = home.appending(path: "Library/Containers/com.apple.Safari/Data/Library")
        let chromeRoot = home.appending(path: "Library/Application Support/Google/Chrome")
        let chromeCacheRoot = home.appending(path: "Library/Caches/Google/Chrome")
        let chromeProfiles = browserProfiles(in: chromeRoot)
        let chromeCacheProfiles = matchingProfileFolders(in: chromeCacheRoot, profileNames: chromeProfiles.map(\.lastPathComponent))
        let firefoxProfiles = home.appending(path: "Library/Application Support/Firefox/Profiles")
        let firefoxCacheProfiles = home.appending(path: "Library/Caches/Firefox/Profiles")

        return [
            PrivacyTarget(
                name: "Safari History",
                detail: "Browsing history database",
                root: safari,
                files: ["History.db", "History.db-wal", "History.db-shm"].map { safari.appending(path: $0) },
                folders: []
            ),
            PrivacyTarget(
                name: "Safari Cookies",
                detail: "Saved website cookie files",
                root: safariContainer,
                files: [
                    safariContainer.appending(path: "Cookies/Cookies.binarycookies"),
                    home.appending(path: "Library/Cookies/Cookies.binarycookies")
                ],
                folders: []
            ),
            PrivacyTarget(
                name: "Safari Cache",
                detail: "Temporary browser cache files",
                root: safariContainer,
                files: [],
                folders: [
                    safariContainer.appending(path: "Caches/com.apple.Safari"),
                    home.appending(path: "Library/Caches/com.apple.Safari")
                ]
            ),
            PrivacyTarget(
                name: "Chrome History",
                detail: "Chrome profile browsing history",
                root: chromeRoot,
                files: profileFiles(in: chromeProfiles, names: ["History", "History-wal", "History-shm"]),
                folders: []
            ),
            PrivacyTarget(
                name: "Chrome Cookies",
                detail: "Chrome profile website cookies",
                root: chromeRoot,
                files: profileFiles(in: chromeProfiles, names: ["Network/Cookies", "Network/Cookies-wal", "Network/Cookies-shm"]),
                folders: []
            ),
            PrivacyTarget(
                name: "Chrome Cache",
                detail: "Chrome profile cache and service worker cache",
                root: chromeCacheRoot,
                files: [],
                folders: profileFolders(in: chromeCacheProfiles, names: ["Cache", "Code Cache"])
                    + profileFolders(in: chromeProfiles, names: ["Service Worker/CacheStorage"])
            ),
            PrivacyTarget(
                name: "Firefox History",
                detail: "Profile browsing history databases",
                root: firefoxProfiles,
                files: profileFiles(in: firefoxProfiles, names: ["places.sqlite", "places.sqlite-wal", "places.sqlite-shm"]),
                folders: []
            ),
            PrivacyTarget(
                name: "Firefox Cookies",
                detail: "Profile website cookie databases",
                root: firefoxProfiles,
                files: profileFiles(in: firefoxProfiles, names: ["cookies.sqlite", "cookies.sqlite-wal", "cookies.sqlite-shm"]),
                folders: []
            ),
            PrivacyTarget(
                name: "Firefox Cache",
                detail: "Temporary profile cache files",
                root: firefoxCacheProfiles,
                files: [],
                folders: profileFolders(in: firefoxCacheProfiles)
            ),
            PrivacyTarget(
                name: "Recent Items",
                detail: "macOS recent document and server lists",
                root: home.appending(path: "Library/Application Support/com.apple.sharedfilelist"),
                files: [],
                folders: [home.appending(path: "Library/Application Support/com.apple.sharedfilelist")]
            )
        ]
    }

    private static func files(for target: PrivacyTarget, exclusions: [String]) -> (files: [URL], blockedLocationCount: Int) {
        var output: [URL] = []
        var seenPaths = Set<String>()
        var blockedLocationCount = 0

        for url in target.files where isRegularFile(url) && !isExcluded(url, exclusions: exclusions) {
            append(url, to: &output, seenPaths: &seenPaths)
        }

        for folder in target.folders where !isExcluded(folder, exclusions: exclusions) {
            let result = regularFiles(in: folder, exclusions: exclusions)
            blockedLocationCount += result.blockedLocationCount
            for file in result.files {
                append(file, to: &output, seenPaths: &seenPaths)
            }
        }

        return (output, blockedLocationCount)
    }

    private static func regularFiles(in folder: URL, exclusions: [String]) -> (files: [URL], blockedLocationCount: Int) {
        guard FileManager.default.fileExists(atPath: folder.path) else { return ([], 0) }

        let keys: Set<URLResourceKey> = [.isRegularFileKey, .isDirectoryKey, .fileSizeKey]
        guard let enumerator = FileManager.default.enumerator(
            at: folder,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return ([], 1)
        }

        var files: [URL] = []
        var blockedLocationCount = 0
        for case let url as URL in enumerator {
            if isExcluded(url, exclusions: exclusions) {
                enumerator.skipDescendants()
                continue
            }
            guard isRegularFile(url) else {
                if isDirectory(url), !FileManager.default.isReadableFile(atPath: url.path) {
                    blockedLocationCount += 1
                    enumerator.skipDescendants()
                }
                continue
            }
            files.append(url)
        }
        return (files, blockedLocationCount)
    }

    private static func profileFiles(in profilesRoot: URL, names: [String]) -> [URL] {
        profileFolders(in: profilesRoot).flatMap { profile in
            names.map { profile.appending(path: $0) }
        }
    }

    private static func profileFiles(in profiles: [URL], names: [String]) -> [URL] {
        profiles.flatMap { profile in
            names.map { profile.appending(path: $0) }
        }
    }

    private static func profileFolders(in profiles: [URL], names: [String]) -> [URL] {
        profiles.flatMap { profile in
            names.map { profile.appending(path: $0) }
        }
    }

    private static func profileFolders(in profilesRoot: URL) -> [URL] {
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: profilesRoot,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return contents.filter { url in
            (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
        }
    }

    private static func browserProfiles(in root: URL) -> [URL] {
        profileFolders(in: root).filter { profile in
            let name = profile.lastPathComponent
            return name == "Default" || name.hasPrefix("Profile ")
        }
    }

    private static func matchingProfileFolders(in root: URL, profileNames: [String]) -> [URL] {
        let names = Set(profileNames)
        return profileFolders(in: root).filter { names.contains($0.lastPathComponent) }
    }

    private static func append(_ url: URL, to output: inout [URL], seenPaths: inout Set<String>) {
        let path = url.standardizedFileURL.path
        guard seenPaths.insert(path).inserted else { return }
        output.append(url)
    }

    private static func isRegularFile(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true
    }

    private static func isDirectory(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
    }

    private static func isExcluded(_ url: URL, exclusions: [String]) -> Bool {
        let path = url.standardizedFileURL.path
        return exclusions.contains { exclusion in
            !exclusion.isEmpty && path.hasPrefix(URL(fileURLWithPath: exclusion).standardizedFileURL.path)
        }
    }
}
