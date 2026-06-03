import Foundation

struct StartupItem: Identifiable, Hashable, Codable {
    enum Scope: String, Codable {
        case user = "User"
        case system = "System"
        case daemon = "Daemon"
        case protectedSystem = "Protected"
        case disabled = "Disabled"
    }

    var id = UUID()
    let label: String
    let url: URL
    let scope: Scope
    let isEnabled: Bool

    var name: String {
        url.deletingPathExtension().lastPathComponent
    }

    var path: String {
        url.path
    }

    var canDisable: Bool {
        isEnabled && scope != .protectedSystem
    }

    var canEnable: Bool {
        !isEnabled && scope == .disabled
    }
}
