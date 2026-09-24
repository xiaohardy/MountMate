import XCTest
@testable import MountMateCore

final class PolicyTests: XCTestCase {
    func testSMBAddressRejectsEmbeddedCredentialsAndSubfolders() {
        XCTAssertNil(SMBAddress("smb://user:password@nas.local/Shared"))
        XCTAssertNil(SMBAddress("smb://nas.local/Shared/Subfolder"))
        XCTAssertNil(SMBAddress("https://nas.local/Shared"))
        XCTAssertNil(SMBAddress("smb://nas.local"))
    }

    func testSMBSourceMatchesConfiguredShareWithDifferentUser() {
        let address = SMBAddress("smb://NAS.local/Shared")!
        XCTAssertEqual(address.key, SMBAddress.key(forMountSource: "//someone@nas.local/Shared"))
        XCTAssertEqual(address.key, SMBAddress.key(forMountSource: "//someone@NAS._smb._tcp.local/Shared"))
        XCTAssertNotEqual(address.key, SMBAddress.key(forMountSource: "//someone@nas.local/Private"))
    }

    func testCleanupProtectsManagedShareAndWhitelistedUSB() {
        let share = ManagedShare(name: "Office", address: "smb://nas.local/Shared", keepConnected: true)
        var settings = AppSettings()
        settings.shares = [share]
        settings.cleanup.kinds = [.diskImage, .usb, .network]
        settings.cleanup.protectedIDs = ["usb:volume-123"]
        let mounts = [
            MountedVolume(name: "Shared", path: "/Volumes/Shared", source: "//other@nas.local/Shared", kind: .network, stableID: "smb:nas.local/shared"),
            MountedVolume(name: "USB", path: "/Volumes/USB", source: "/dev/disk4s1", kind: .usb, stableID: "usb:volume-123"),
            MountedVolume(name: "Installer", path: "/Volumes/Installer", source: "/dev/disk5s1", kind: .diskImage, stableID: "image:/tmp/Installer.dmg")
        ]
        XCTAssertEqual(CleanupPolicy.candidates(from: mounts, settings: settings).map(\.name), ["Installer"])
    }

    func testDailyCleanupRunsOnceNearTimeAndSkipsMissedWake() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        let day = calendar.date(from: DateComponents(year: 2026, month: 9, day: 24, hour: 3))!
        let key = DailyCleanup.dayKey(for: day, calendar: calendar)
        XCTAssertTrue(DailyCleanup.shouldRun(at: day.addingTimeInterval(90), hour: 3, minute: 0, lastRunDay: nil, calendar: calendar))
        XCTAssertFalse(DailyCleanup.shouldRun(at: day.addingTimeInterval(90), hour: 3, minute: 0, lastRunDay: key, calendar: calendar))
        XCTAssertFalse(DailyCleanup.shouldRun(at: day.addingTimeInterval(6 * 3600), hour: 3, minute: 0, lastRunDay: nil, calendar: calendar))
    }

    func testUSBHardDriveIsNotClassifiedAsFlashDrive() {
        XCTAssertEqual(VolumeClassification.localKind(bus: "USB", isInternal: false, isRemovable: true, isDiskImage: false), .usb)
        XCTAssertEqual(VolumeClassification.localKind(bus: "USB", isInternal: false, isRemovable: false, isDiskImage: false), .external)
        XCTAssertEqual(VolumeClassification.localKind(bus: "USB", isInternal: false, isRemovable: nil, isDiskImage: false), .external)
        XCTAssertNil(VolumeClassification.localKind(bus: "PCI-Express", isInternal: true, isRemovable: false, isDiskImage: false))
        XCTAssertEqual(VolumeClassification.localKind(bus: "Virtual", isInternal: true, isRemovable: false, isDiskImage: true), .diskImage)
    }

    func testReplacedMountAtSamePathHasDifferentSelectionIdentity() {
        let old = MountedVolume(name: "Drive", path: "/Volumes/Drive", source: "/dev/disk4s1", kind: .usb, stableID: "old")
        let replacement = MountedVolume(name: "Drive", path: "/Volumes/Drive", source: "/dev/disk9s1", kind: .usb, stableID: "new")
        XCTAssertNotEqual(old.id, replacement.id)
    }
}
