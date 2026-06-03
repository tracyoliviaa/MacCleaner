import Foundation
import AppKit

enum CPUService {
    static func topProcesses(limit: Int = 15) throws -> [ProcessItem] {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(filePath: "/bin/ps")
        process.arguments = ["-Arco", "pid,pcpu,rss,comm"]
        process.standardOutput = pipe
        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        return output
            .split(separator: "\n")
            .dropFirst()
            .compactMap(parseProcessLine)
            .sorted { $0.cpuPercent > $1.cpuPercent }
            .prefix(limit)
            .map { $0 }
    }

    static func forceQuit(pid: Int32) -> Bool {
        guard let app = NSRunningApplication(processIdentifier: pid) else {
            return false
        }
        return app.forceTerminate()
    }

    private static func parseProcessLine(_ line: Substring) -> ProcessItem? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        let parts = trimmed.split(separator: " ", maxSplits: 3, omittingEmptySubsequences: true)
        guard parts.count == 4,
              let pid = Int32(parts[0]),
              let cpu = Double(parts[1]),
              let rssKB = Double(parts[2]) else { return nil }

        return ProcessItem(pid: pid, name: String(parts[3]), cpuPercent: cpu, memoryMB: rssKB / 1024)
    }
}
