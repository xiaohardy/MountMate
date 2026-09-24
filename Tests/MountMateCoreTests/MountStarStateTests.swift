import XCTest
@testable import MountMateCore

final class MountStarStateTests: XCTestCase {
    func testEmptySnapshotHasTwelveVisibleDimPositions() {
        let snapshot = MountStarSnapshot.empty
        XCTAssertEqual(snapshot.slots.count, 12)
        XCTAssertTrue(snapshot.slots.allSatisfy { !$0.isLit })
        XCTAssertEqual(snapshot.mountedCount, 0)
        XCTAssertEqual(snapshot.overflowCount, 0)
    }

    func testFixedSharesStartAtTwelveOClockAndDeduplicateScannedMounts() {
        let office = ManagedShare(name: "Office", address: "smb://NAS.local/Shared")
        let backup = ManagedShare(name: "Backup", address: "smb://nas.local/Backup")
        let mountedOffice = volume("office", source: "//someone@nas.local/Shared", kind: .network)
        let usb = volume("usb")
        var state = MountStarState()

        let snapshot = state.update(shares: [office, backup], mounts: [usb, mountedOffice])

        XCTAssertEqual(snapshot.slots.count, 12)
        XCTAssertEqual(snapshot.slots.map(\.index), Array(0..<12))
        XCTAssertEqual(snapshot.slots[0].shareID, office.id)
        XCTAssertEqual(snapshot.slots[0].volume, mountedOffice)
        XCTAssertTrue(snapshot.slots[0].isLit)
        XCTAssertEqual(snapshot.slots[1].shareID, backup.id)
        XCTAssertFalse(snapshot.slots[1].isLit)
        XCTAssertEqual(snapshot.slots[2].volumeStableID, usb.stableID)
        XCTAssertTrue(snapshot.slots[2].isLit)
        XCTAssertEqual(snapshot.mountedCount, 2)
        XCTAssertEqual(snapshot.overflowCount, 0)
        XCTAssertEqual(snapshot.slots.filter(\.isLit).count, 2)
    }

    func testUnmanagedMountKeepsItsPositionAcrossReorderedScansAndReconnect() {
        let a = volume("a")
        let b = volume("b")
        var state = MountStarState()

        _ = state.update(shares: [], mounts: [a, b])
        let reversed = state.update(shares: [], mounts: [b, a])
        XCTAssertEqual(reversed.slots[0].volumeStableID, a.stableID)
        XCTAssertEqual(reversed.slots[1].volumeStableID, b.stableID)

        let disconnected = state.update(shares: [], mounts: [b])
        XCTAssertEqual(disconnected.slots[0].volumeStableID, a.stableID)
        XCTAssertFalse(disconnected.slots[0].isLit)
        XCTAssertTrue(disconnected.slots[1].isLit)

        let reconnected = state.update(shares: [], mounts: [b, a])
        XCTAssertEqual(reconnected.slots[0].volume, a)
        XCTAssertTrue(reconnected.slots[0].isLit)
        XCTAssertTrue(reconnected.slots[1].isLit)
    }

    func testUnavailableMountsAreDimEvenWhileListedByScanner() {
        let share = ManagedShare(name: "Office", address: "smb://nas.local/Shared")
        let network = volume("network", source: "//user@nas.local/Shared", kind: .network)
        let usb = volume("usb")
        var state = MountStarState()

        let snapshot = state.update(
            shares: [share], mounts: [network, usb],
            unavailableShareIDs: [share.id], unavailableVolumeIDs: [usb.stableID]
        )

        XCTAssertFalse(snapshot.slots[0].isLit)
        XCTAssertFalse(snapshot.slots[1].isLit)
        XCTAssertEqual(snapshot.mountedCount, 0)
        let recovered = state.update(shares: [share], mounts: [network, usb])
        XCTAssertTrue(recovered.slots[0].isLit)
        XCTAssertTrue(recovered.slots[1].isLit)
    }

    func testCapacityKeepsExistingPositionsAndReportsOverflow() {
        let mounts = (0..<13).map { volume(String(format: "%02d", $0)) }
        var state = MountStarState()

        let full = state.update(shares: [], mounts: mounts)
        XCTAssertEqual(full.slots.filter(\.isLit).count, 12)
        XCTAssertEqual(full.mountedCount, 13)
        XCTAssertEqual(full.overflowCount, 1)

        let remaining = state.update(shares: [], mounts: Array(mounts.dropFirst()))
        XCTAssertEqual(remaining.slots.filter(\.isLit).count, 12)
        XCTAssertEqual(remaining.overflowCount, 0)
        XCTAssertEqual(remaining.slots[1].volumeStableID, mounts[1].stableID)
        XCTAssertEqual(remaining.slots[0].volumeStableID, mounts[12].stableID)
    }

    func testAddingFixedShareDisplacesOnlyNecessaryUnmanagedMounts() {
        let a = volume("a")
        let b = volume("b")
        let share = ManagedShare(name: "Office", address: "smb://nas.local/Shared")
        var state = MountStarState()
        _ = state.update(shares: [], mounts: [a, b])

        let snapshot = state.update(shares: [share], mounts: [b, a])
        XCTAssertEqual(snapshot.slots[0].shareID, share.id)
        XCTAssertEqual(snapshot.slots[1].volumeStableID, b.stableID)
        XCTAssertEqual(snapshot.slots[2].volumeStableID, a.stableID)
        XCTAssertEqual(snapshot.mountedCount, 2)
    }

    func testConfiguringAnOrdinarySMBMountClearsItsOldPosition() {
        let network = volume("network", source: "//user@nas.local/Shared", kind: .network)
        let share = ManagedShare(name: "Office", address: "smb://nas.local/Shared")
        var state = MountStarState()
        _ = state.update(shares: [], mounts: [network])

        let snapshot = state.update(shares: [share], mounts: [network])
        XCTAssertEqual(snapshot.slots[0].shareID, share.id)
        XCTAssertTrue(snapshot.slots[0].isLit)
        XCTAssertTrue(snapshot.slots.dropFirst().allSatisfy { $0.volumeStableID == nil })
        XCTAssertEqual(snapshot.mountedCount, 1)

        var disconnectedState = MountStarState()
        _ = disconnectedState.update(shares: [], mounts: [network])
        _ = disconnectedState.update(shares: [], mounts: [])
        let disconnected = disconnectedState.update(shares: [share], mounts: [])
        XCTAssertFalse(disconnected.slots[0].isLit)
        XCTAssertTrue(disconnected.slots.dropFirst().allSatisfy { $0.volumeStableID == nil })
    }

    func testMoreThanTwelveFixedSharesTruncatesSlotsAndCountsMountedOverflow() {
        let shares = (0..<13).map { ManagedShare(name: "Share \($0)", address: "smb://nas.local/share\($0)") }
        let hidden = volume("hidden", source: "//user@nas.local/share12", kind: .network)
        var state = MountStarState()

        let snapshot = state.update(shares: shares, mounts: [hidden])
        XCTAssertEqual(snapshot.slots.count, 12)
        XCTAssertEqual(snapshot.slots.map(\.shareID), shares.prefix(12).map(\.id))
        XCTAssertEqual(snapshot.slots.filter(\.isLit).count, 0)
        XCTAssertEqual(snapshot.mountedCount, 1)
        XCTAssertEqual(snapshot.overflowCount, 1)
    }

    private func volume(_ id: String, source: String? = nil, kind: MountKind = .usb) -> MountedVolume {
        MountedVolume(name: id, path: "/Volumes/\(id)", source: source ?? "/dev/\(id)", kind: kind, stableID: id)
    }
}
