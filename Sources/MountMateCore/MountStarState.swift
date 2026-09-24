import Foundation

/// One of the twelve clockwise positions, starting at twelve o'clock.
public struct MountStarSlot: Equatable, Sendable {
    public let index: Int
    public let shareID: UUID?
    /// The remembered identity of an ordinary mount, even after it disappears.
    public let volumeStableID: String?
    public let volume: MountedVolume?
    public let isLit: Bool
}

/// An icon-ready view of available mounts. `mountedCount` includes mounts
/// beyond the twelve visible positions; `overflowCount` counts those hidden mounts.
public struct MountStarSnapshot: Equatable, Sendable {
    public let slots: [MountStarSlot]
    public let mountedCount: Int
    public let overflowCount: Int

    public static let empty: MountStarSnapshot = {
        var state = MountStarState()
        return state.update(shares: [], mounts: [])
    }()
}

/// Keeps ordinary mounts in the same star position across reordered scans and
/// temporary disconnects. Keep one instance for the lifetime of the app model.
public struct MountStarState: Sendable {
    public static let capacity = 12

    private var rememberedSlots: [String: Int] = [:]
    private var smbKeyByOrdinaryID: [String: String] = [:]
    private var lastSeen: [String: Int] = [:]
    private var scanNumber = 0

    public init() {}

    /// Configured shares reserve the first positions in their supplied order.
    /// The unavailable sets dim a star when a listed mount is known to be unhealthy.
    /// `unavailableVolumeIDs` uses `MountedVolume.stableID` values.
    public mutating func update(
        shares: [ManagedShare],
        mounts: [MountedVolume],
        unavailableShareIDs: Set<UUID> = [],
        unavailableVolumeIDs: Set<String> = []
    ) -> MountStarSnapshot {
        scanNumber += 1
        let fixedCount = min(shares.count, Self.capacity)

        // A configured SMB share is one logical mount, even when its source is
        // also present in the scanner output (or appears there more than once).
        var shareIDByKey: [String: UUID] = [:]
        for share in shares {
            if let key = SMBAddress(share.address)?.key, shareIDByKey[key] == nil {
                shareIDByKey[key] = share.id
            }
        }
        var managedMounts: [UUID: MountedVolume] = [:]
        var ordinaryMounts: [String: MountedVolume] = [:]
        let orderedMounts = mounts.sorted {
            if $0.name != $1.name { return $0.name < $1.name }
            return $0.stableID < $1.stableID
        }
        for mount in orderedMounts {
            if let key = SMBAddress.key(forMountSource: mount.source),
               let shareID = shareIDByKey[key] {
                if managedMounts[shareID] == nil { managedMounts[shareID] = mount }
            } else if ordinaryMounts[mount.stableID] == nil {
                ordinaryMounts[mount.stableID] = mount
                smbKeyByOrdinaryID[mount.stableID] = SMBAddress.key(forMountSource: mount.source)
            }
        }

        // A volume that becomes a configured share must leave its old ordinary
        // position, including when it disconnected just before configuration.
        let managedVolumeIDs = Set(managedMounts.values.map(\.stableID))
        let configuredSMBKeys = Set(shareIDByKey.keys)
        rememberedSlots = rememberedSlots.filter { id, _ in
            !managedVolumeIDs.contains(id)
                && !configuredSMBKeys.contains(smbKeyByOrdinaryID[id] ?? "")
        }

        let availableOrdinaryIDs = Set(ordinaryMounts.keys.filter { !unavailableVolumeIDs.contains($0) })
        for id in availableOrdinaryIDs { lastSeen[id] = scanNumber }

        var occupied = [String?](repeating: nil, count: Self.capacity)
        var placed = Set<String>()

        func place(_ id: String, at index: Int) {
            occupied[index] = id
            placed.insert(id)
        }

        // Preserve the positions of currently mounted volumes first.
        for (id, index) in rememberedSlots.sorted(by: { $0.value < $1.value })
        where availableOrdinaryIDs.contains(id) && index >= fixedCount && occupied[index] == nil {
            place(id, at: index)
        }
        // Then retain dim positions so reconnecting a volume lights the same star.
        for (id, index) in rememberedSlots.sorted(by: { $0.value < $1.value })
        where !availableOrdinaryIDs.contains(id) && index >= fixedCount && occupied[index] == nil {
            place(id, at: index)
        }

        func firstFreePosition() -> Int? {
            (fixedCount..<Self.capacity).first { occupied[$0] == nil }
        }

        func positionForAvailableMount() -> Int? {
            if let free = firstFreePosition() { return free }
            // When all positions have history, the least recently mounted dim
            // volume gives way to a newly mounted one.
            return (fixedCount..<Self.capacity)
                .filter { index in
                    guard let id = occupied[index] else { return false }
                    return !availableOrdinaryIDs.contains(id)
                }
                .min { lhs, rhs in
                    let left = lastSeen[occupied[lhs]!] ?? 0
                    let right = lastSeen[occupied[rhs]!] ?? 0
                    return left == right ? lhs < rhs : left < right
                }
        }

        // A new fixed share can displace a volume from an early position.
        // Rehome those volumes before assigning positions to first-time mounts.
        let displacedAvailable = rememberedSlots
            .filter { availableOrdinaryIDs.contains($0.key) && !placed.contains($0.key) }
            .sorted { $0.value < $1.value }
            .map(\.key)
        let firstTimeAvailable = availableOrdinaryIDs
            .filter { rememberedSlots[$0] == nil }
            .sorted { lhs, rhs in
                let left = ordinaryMounts[lhs]!
                let right = ordinaryMounts[rhs]!
                return left.name == right.name ? lhs < rhs : left.name < right.name
            }
        for id in displacedAvailable + firstTimeAvailable {
            guard let index = positionForAvailableMount() else { continue }
            if let evicted = occupied[index] { placed.remove(evicted) }
            place(id, at: index)
        }

        let displacedDim = rememberedSlots
            .filter { !availableOrdinaryIDs.contains($0.key) && !placed.contains($0.key) }
            .sorted { $0.value < $1.value }
            .map(\.key)
        for id in displacedDim {
            guard let index = firstFreePosition() else { break }
            place(id, at: index)
        }

        rememberedSlots = Dictionary(uniqueKeysWithValues: occupied.enumerated().compactMap { index, id in
            id.map { ($0, index) }
        })
        lastSeen = lastSeen.filter { rememberedSlots[$0.key] != nil }
        smbKeyByOrdinaryID = smbKeyByOrdinaryID.filter { rememberedSlots[$0.key] != nil }

        let slots = (0..<Self.capacity).map { index -> MountStarSlot in
            if index < fixedCount {
                let share = shares[index]
                let volume = managedMounts[share.id]
                let isLit = volume.map {
                    !unavailableShareIDs.contains(share.id) && !unavailableVolumeIDs.contains($0.stableID)
                } ?? false
                return MountStarSlot(
                    index: index, shareID: share.id, volumeStableID: volume?.stableID,
                    volume: volume, isLit: isLit
                )
            }
            let id = occupied[index]
            let volume = id.flatMap { ordinaryMounts[$0] }
            let isLit = id.map { volume != nil && !unavailableVolumeIDs.contains($0) } ?? false
            return MountStarSlot(
                index: index, shareID: nil, volumeStableID: id, volume: volume,
                isLit: isLit
            )
        }
        let availableManagedCount = managedMounts.filter { id, volume in
            !unavailableShareIDs.contains(id) && !unavailableVolumeIDs.contains(volume.stableID)
        }.count
        let mountedCount = availableManagedCount + availableOrdinaryIDs.count
        return MountStarSnapshot(
            slots: slots,
            mountedCount: mountedCount,
            overflowCount: max(0, mountedCount - slots.filter(\.isLit).count)
        )
    }
}
