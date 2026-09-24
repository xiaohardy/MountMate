import Foundation

public enum MountKind: String, CaseIterable, Codable, Hashable, Identifiable, Sendable {
    case diskImage
    case usb
    case external
    case network

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .diskImage: return "磁盘镜像"
        case .usb: return "U 盘"
        case .external: return "其他外置磁盘"
        case .network: return "网络共享"
        }
    }
}

public struct MountedVolume: Identifiable, Equatable, Sendable {
    public let name: String
    public let path: String
    public let source: String
    public let kind: MountKind
    public let stableID: String

    public var id: String { "\(path.utf8.count):\(path)\(source)" }

    public init(name: String, path: String, source: String, kind: MountKind, stableID: String) {
        self.name = name
        self.path = path
        self.source = source
        self.kind = kind
        self.stableID = stableID
    }
}

public struct ManagedShare: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var address: String
    public var username: String
    public var guestAccess: Bool
    /// Imported Finder mounts can first try credentials already stored by macOS.
    /// Optional so settings written by older MountMate versions still decode.
    public var useSystemCredentials: Bool?
    public var keepConnected: Bool
    public var paused: Bool
    public var protectFromCleanup: Bool

    public init(id: UUID = UUID(), name: String, address: String, username: String = "", guestAccess: Bool = false, useSystemCredentials: Bool? = nil, keepConnected: Bool = true, paused: Bool = false, protectFromCleanup: Bool = true) {
        self.id = id
        self.name = name
        self.address = address
        self.username = username
        self.guestAccess = guestAccess
        self.useSystemCredentials = useSystemCredentials
        self.keepConnected = keepConnected
        self.paused = paused
        self.protectFromCleanup = protectFromCleanup
    }
}

public struct CleanupSettings: Codable, Equatable, Sendable {
    public var kinds: Set<MountKind> = [.diskImage, .usb]
    public var protectedIDs: Set<String> = []
    public var dailyEnabled = false
    public var hour = 3
    public var minute = 0

    public init() {}
}

public struct EventRecord: Identifiable, Codable, Equatable, Sendable {
    public var id = UUID()
    public var date = Date()
    public var message: String

    public init(message: String) { self.message = message }
}

public struct AppSettings: Codable, Equatable, Sendable {
    public var shares: [ManagedShare] = []
    /// Nil means follow the current macOS language.
    public var language: AppLanguage?
    public var cleanup = CleanupSettings()
    public var lastCleanupDay: String?
    public var events: [EventRecord] = []

    public init() {}
}
