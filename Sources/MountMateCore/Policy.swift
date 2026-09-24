import Foundation

public struct SMBAddress: Equatable {
    public let url: URL
    public let key: String

    public init?(_ raw: String) {
        guard let parts = URLComponents(string: raw.trimmingCharacters(in: .whitespacesAndNewlines)),
              parts.scheme?.lowercased() == "smb",
              let host = parts.host, !host.isEmpty,
              parts.user == nil, parts.password == nil,
              parts.query == nil, parts.fragment == nil,
              parts.port == nil,
              let url = parts.url else { return nil }
        let segments = parts.path.split(separator: "/", omittingEmptySubsequences: true)
        guard segments.count == 1,
              let share = String(segments[0]).removingPercentEncoding,
              !share.isEmpty,
              !share.contains("/") else { return nil }
        self.url = url
        self.key = "\(Self.normalizedHost(host))/\(share.lowercased())"
    }

    public static func key(forMountSource source: String) -> String? {
        let withoutScheme: String
        if source.hasPrefix("//") {
            withoutScheme = String(source.dropFirst(2))
        } else if source.lowercased().hasPrefix("smb://") {
            withoutScheme = String(source.dropFirst(6))
        } else {
            return nil
        }
        let segments = withoutScheme.split(separator: "/", omittingEmptySubsequences: true)
        guard segments.count >= 2 else { return nil }
        let hostAndUser = String(segments[0])
        let host = hostAndUser.split(separator: "@").last.map(String.init) ?? ""
        let share = String(segments[1]).removingPercentEncoding ?? ""
        guard !host.isEmpty, !share.isEmpty else { return nil }
        return "\(normalizedHost(host))/\(share.lowercased())"
    }

    private static func normalizedHost(_ host: String) -> String {
        host.lowercased().replacingOccurrences(of: "._smb._tcp.", with: ".")
    }
}

public enum CleanupPolicy {
    public static func candidates(from mounts: [MountedVolume], settings: AppSettings) -> [MountedVolume] {
        mounts.filter { mount in
            guard settings.cleanup.kinds.contains(mount.kind),
                  !settings.cleanup.protectedIDs.contains(mount.stableID) else { return false }
            let key = SMBAddress.key(forMountSource: mount.source)
            return !settings.shares.contains { share in
                SMBAddress(share.address)?.key == key && (share.keepConnected || share.protectFromCleanup)
            }
        }
    }

    public static func isProtected(_ mount: MountedVolume, settings: AppSettings) -> Bool {
        var copy = settings
        copy.cleanup.kinds = [mount.kind]
        return !candidates(from: [mount], settings: copy).contains(mount)
    }
}

public enum DailyCleanup {
    public static func dayKey(for date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    public static func shouldRun(at date: Date, hour: Int, minute: Int, lastRunDay: String?, calendar: Calendar = .current) -> Bool {
        guard (0...23).contains(hour), (0...59).contains(minute),
              lastRunDay != dayKey(for: date, calendar: calendar) else { return false }
        var parts = calendar.dateComponents([.year, .month, .day], from: date)
        parts.hour = hour
        parts.minute = minute
        parts.second = 0
        guard let scheduled = calendar.date(from: parts) else { return false }
        let elapsed = date.timeIntervalSince(scheduled)
        return elapsed >= 0 && elapsed < 5 * 60
    }
}

public enum VolumeClassification {
    public static func localKind(bus: String, isInternal: Bool?, isRemovable: Bool?, isDiskImage: Bool) -> MountKind? {
        if isDiskImage { return .diskImage }
        guard isInternal == false else { return nil }
        if bus.lowercased() == "usb" && isRemovable == true { return .usb }
        return .external
    }
}
