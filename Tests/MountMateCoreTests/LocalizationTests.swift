import Foundation
import XCTest
@testable import MountMateCore

final class LocalizationTests: XCTestCase {
    func testCatalogsCoverEverySupportedLanguageAndUseTheSamePlaceholders() throws {
        let english = L10n.catalog(.english)
        XCTAssertGreaterThan(english.count, 80)
        XCTAssertEqual(english["pinnedMounts"], "Pinned mounts")
        XCTAssertEqual(english["addFromCurrentMounts"], "Add from current mounts")
        XCTAssertEqual(english["scanCurrentMounts"], "Scan current mounts")

        for language in AppLanguage.allCases where language != .system {
            let catalog = L10n.catalog(language)
            XCTAssertEqual(Set(catalog.keys), Set(english.keys), "Incomplete \(language.rawValue) catalog")
            for (key, value) in catalog {
                XCTAssertFalse(value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "Blank \(key) in \(language.rawValue)")
                XCTAssertEqual(placeholders(in: value), placeholders(in: english[key]!),
                               "Placeholder mismatch for \(key) in \(language.rawValue)")
            }
        }
        XCTAssertEqual(L10n.catalog(.simplifiedChinese)["pinnedMounts"], "固定挂载")
    }

    func testSystemLanguageResolvesScriptRegionAndFallback() {
        XCTAssertEqual(L10n.resolve(.system, preferred: ["zh-Hant-HK"]), .traditionalChinese)
        XCTAssertEqual(L10n.resolve(.system, preferred: ["zh-TW"]), .traditionalChinese)
        XCTAssertEqual(L10n.resolve(.system, preferred: ["zh-Hans-CN"]), .simplifiedChinese)
        XCTAssertEqual(L10n.resolve(.system, preferred: ["zh-CN"]), .simplifiedChinese)
        XCTAssertEqual(L10n.resolve(.system, preferred: ["pt-PT"]), .portuguese)
        XCTAssertEqual(L10n.resolve(.system, preferred: ["it-IT", "de-DE"]), .german)
        XCTAssertEqual(L10n.resolve(.system, preferred: ["it-IT"]), .english)
        XCTAssertEqual(L10n.resolve(.japanese, preferred: ["en-US"]), .japanese)
    }

    func testPlaceholderReplacementDoesNotInterpretArgumentContents() {
        let result = L10n.text("eventUnmountFailed", language: .english, arguments: [
            "reason": "manual {name}", "name": "NAS {error}", "error": "busy"
        ])
        XCTAssertEqual(result, "manual {name} · NAS {error}: Unmount failed, busy")
        XCTAssertEqual(L10n.text("eventUnmountFailed", language: .english),
                       "{reason} · {name}: Unmount failed, {error}")
    }

    func testUnknownKeyAndKnownTranslation() {
        XCTAssertEqual(L10n.text("unknown.key", language: .english), "unknown.key")
        XCTAssertEqual(L10n.text("language", language: .simplifiedChinese), "语言")
        XCTAssertEqual(L10n.text("language", language: .french), "Langue")
    }

    private func placeholders(in value: String) -> Set<String> {
        let expression = try! NSRegularExpression(pattern: #"\{([a-zA-Z][a-zA-Z0-9_]*)\}"#)
        let matches = expression.matches(in: value, range: NSRange(value.startIndex..., in: value))
        return Set(matches.compactMap { Range($0.range(at: 1), in: value).map { String(value[$0]) } })
    }
}
