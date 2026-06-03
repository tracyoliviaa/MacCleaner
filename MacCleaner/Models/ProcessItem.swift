import Foundation

struct ProcessItem: Identifiable, Hashable {
    let id = UUID()
    let pid: Int32
    let name: String
    let cpuPercent: Double
    let memoryMB: Double
}
