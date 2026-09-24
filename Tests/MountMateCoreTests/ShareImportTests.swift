import XCTest
@testable import MountMateCore

final class ShareImportTests: XCTestCase {
    func testImportsOnlySMBAndPreservesMountedAddressAndUsername() {
        let smb = MountedVolume(name: "ExampleFiles", path: "/Volumes/ExampleFiles",
                                source: "//demo@SampleServer._smb._tcp.local/ExampleFiles",
                                kind: .network, stableID: "network:sampleserver.local/examplefiles")
        let nfs = MountedVolume(name: "Research", path: "/Volumes/Research",
                                source: "server:/export/research", kind: .network,
                                stableID: "network:nfs")
        let image = MountedVolume(name: "Installer", path: "/Volumes/Installer",
                                  source: "/dev/disk8s1", kind: .diskImage,
                                  stableID: "image:installer")

        let candidate = ShareImport.candidate(from: smb)
        XCTAssertEqual(candidate?.name, "ExampleFiles")
        XCTAssertEqual(candidate?.address, "smb://sampleserver._smb._tcp.local/ExampleFiles")
        XCTAssertEqual(candidate?.username, "demo")
        XCTAssertEqual(candidate?.key, SMBAddress.key(forMountSource: smb.source))
        XCTAssertNil(ShareImport.candidate(from: nfs))
        XCTAssertNil(ShareImport.candidate(from: image))
    }

    func testDuplicateExistingSharesAndRepeatedMountsAreExcluded() {
        let mounted = MountedVolume(name: "Shared", path: "/Volumes/Shared",
                                    source: "//admin@DEMOBOX._smb._tcp.local/Shared",
                                    kind: .network, stableID: "network:demobox.local/shared")
        let duplicate = MountedVolume(name: "Shared 2", path: "/Volumes/Shared 2",
                                      source: "//other@demobox.local/Shared",
                                      kind: .network, stableID: "network:demobox.local/shared")
        let existing = ManagedShare(name: "Office", address: "smb://demobox.local/Shared")

        XCTAssertEqual(ShareImport.candidates(from: [mounted, duplicate], excluding: []).count, 1)
        XCTAssertTrue(ShareImport.candidates(from: [mounted, duplicate], excluding: [existing]).isEmpty)
    }

    func testMalformedSMBMountSourceIsNotImportable() {
        for source in ["//server", "//server/share/subfolder", "smb://server/share?x=1"] {
            let mount = MountedVolume(name: "Invalid", path: "/Volumes/Invalid", source: source,
                                      kind: .network, stableID: source)
            XCTAssertNil(ShareImport.candidate(from: mount), source)
        }
    }

    func testExistingShareSettingsDecodeWithoutNewCredentialAndLanguageFields() throws {
        var original = AppSettings()
        original.shares = [ManagedShare(name: "Office", address: "smb://nas.local/Shared",
                                        username: "demo", useSystemCredentials: true)]
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(original)) as? [String: Any])
        var shares = try XCTUnwrap(object["shares"] as? [[String: Any]])
        shares[0].removeValue(forKey: "useSystemCredentials")
        object["shares"] = shares
        object.removeValue(forKey: "language")

        let decoded = try JSONDecoder().decode(AppSettings.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertNil(decoded.language)
        XCTAssertNil(decoded.shares[0].useSystemCredentials)
        XCTAssertEqual(decoded.shares[0].name, "Office")
    }
}
