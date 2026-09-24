import Foundation
import XCTest
@testable import MountMate
import MountMateCore

final class SettingsStoreTests: XCTestCase {
    func testCorruptSettingsRemainUntouchedWhenLoadFails() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("mountmate-settings-test-\(UUID())")
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = directory.appendingPathComponent("settings.json")
        let badData = Data("invalid settings".utf8)
        try badData.write(to: file)

        XCTAssertThrowsError(try SettingsStore.load(from: file))
        XCTAssertEqual(try Data(contentsOf: file), badData)
    }

    func testSavedSettingsAndDirectoryHavePrivatePermissions() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("mountmate-settings-test-\(UUID())")
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("settings.json")

        try SettingsStore.save(AppSettings(), to: file)

        let loaded = try SettingsStore.load(from: file)
        XCTAssertEqual(loaded, AppSettings())
        let fileMode = try XCTUnwrap(FileManager.default.attributesOfItem(atPath: file.path)[.posixPermissions] as? NSNumber)
        let directoryMode = try XCTUnwrap(FileManager.default.attributesOfItem(atPath: directory.path)[.posixPermissions] as? NSNumber)
        XCTAssertEqual(fileMode.intValue & 0o777, 0o600)
        XCTAssertEqual(directoryMode.intValue & 0o777, 0o700)
    }
}
