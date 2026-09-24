import Foundation

public struct SMBImportCandidate: Identifiable, Equatable, Sendable {
    public let volume: MountedVolume
    public let name: String
    public let address: String
    public let username: String
    public let key: String

    public var id: String { volume.id }
}

public enum ShareImport {
    public static func candidate(from volume: MountedVolume) -> SMBImportCandidate? {
        guard volume.kind == .network else { return nil }
        let source = volume.source
        let urlString: String
        if source.hasPrefix("//") {
            urlString = "smb:" + source
        } else if source.lowercased().hasPrefix("smb://") {
            urlString = source
        } else {
            return nil
        }
        guard let parts = URLComponents(string: urlString),
              parts.scheme?.lowercased() == "smb",
              let host = parts.host, !host.isEmpty,
              parts.password == nil, parts.query == nil, parts.fragment == nil, parts.port == nil else {
            return nil
        }
        let segments = parts.path.split(separator: "/", omittingEmptySubsequences: true)
        guard segments.count == 1 else { return nil }
        let share = String(segments[0])
        var addressParts = URLComponents()
        addressParts.scheme = "smb"
        addressParts.host = host.lowercased()
        addressParts.path = "/" + share
        guard let address = addressParts.url?.absoluteString,
              let parsed = SMBAddress(address),
              parsed.key == SMBAddress.key(forMountSource: source) else { return nil }
        return SMBImportCandidate(volume: volume, name: volume.name, address: address,
                                  username: parts.user ?? "", key: parsed.key)
    }

    public static func candidates(from volumes: [MountedVolume], excluding shares: [ManagedShare]) -> [SMBImportCandidate] {
        var seen = Set(shares.compactMap { SMBAddress($0.address)?.key })
        return volumes.compactMap { volume in
            guard let candidate = candidate(from: volume), seen.insert(candidate.key).inserted else { return nil }
            return candidate
        }
    }
}
