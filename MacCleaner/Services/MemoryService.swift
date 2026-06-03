import Foundation
import Darwin
import MachO

struct MemorySnapshot {
    let total: UInt64
    let free: UInt64
    let active: UInt64
    let inactive: UInt64
    let wired: UInt64

    var used: UInt64 { total > free ? total - free : 0 }
    var usedFraction: Double { total == 0 ? 0 : Double(used) / Double(total) }

    var pressure: String {
        let freeRatio = total == 0 ? 1 : Double(free) / Double(total)
        if freeRatio < 0.08 { return "Critical" }
        if freeRatio < 0.18 { return "Warning" }
        return "Normal"
    }
}

enum MemoryService {
    struct PurgeResult {
        let succeeded: Bool
        let message: String
    }

    static func snapshot() -> MemorySnapshot {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride)
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }

        var pageSize: vm_size_t = 0
        host_page_size(mach_host_self(), &pageSize)
        let page = UInt64(pageSize)

        guard result == KERN_SUCCESS else {
            let total = ProcessInfo.processInfo.physicalMemory
            return MemorySnapshot(total: total, free: 0, active: 0, inactive: 0, wired: 0)
        }

        let free = UInt64(stats.free_count) * page
        let active = UInt64(stats.active_count) * page
        let inactive = UInt64(stats.inactive_count) * page
        let wired = UInt64(stats.wire_count) * page

        return MemorySnapshot(
            total: ProcessInfo.processInfo.physicalMemory,
            free: free,
            active: active,
            inactive: inactive,
            wired: wired
        )
    }

    static func purgeInactiveMemory() async -> PurgeResult {
        let process = Process()
        let errorPipe = Pipe()
        process.executableURL = URL(filePath: "/usr/bin/sudo")
        process.arguments = ["-n", "/usr/sbin/purge"]
        process.standardError = errorPipe

        do {
            try process.run()
        } catch {
            return PurgeResult(succeeded: false, message: "Could not start memory purge.")
        }

        process.waitUntilExit()
        if process.terminationStatus == 0 {
            return PurgeResult(succeeded: true, message: "Memory purge completed.")
        }

        let data = errorPipe.fileHandleForReading.readDataToEndOfFile()
        let errorText = String(data: data, encoding: .utf8) ?? ""
        if errorText.lowercased().contains("password") || process.terminationStatus == 1 {
            return PurgeResult(succeeded: false, message: "Purge needs administrator permission. Run the app from Xcode or Terminal if you want to allow sudo prompts.")
        }
        return PurgeResult(succeeded: false, message: "Memory purge failed.")
    }
}
