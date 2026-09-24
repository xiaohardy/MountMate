import Foundation

public enum AppLanguage: String, CaseIterable, Codable, Identifiable, Sendable {
    case system
    case english = "en"
    case spanish = "es"
    case french = "fr"
    case simplifiedChinese = "zh-Hans"
    case traditionalChinese = "zh-Hant"
    case german = "de"
    case japanese = "ja"
    case portuguese = "pt-BR"

    public var id: String { rawValue }

    public var nativeName: String {
        switch self {
        case .system: return "System"
        case .english: return "English"
        case .spanish: return "Español"
        case .french: return "Français"
        case .simplifiedChinese: return "简体中文"
        case .traditionalChinese: return "繁體中文"
        case .german: return "Deutsch"
        case .japanese: return "日本語"
        case .portuguese: return "Português (Brasil)"
        }
    }
}

public enum L10n {
    private static var resourceBundle: Bundle {
        // The installed app must contain its own language resources. Do not
        // silently read SwiftPM resources from a development checkout.
        if Bundle.main.bundleURL.pathExtension == "app" {
            guard let url = Bundle.main.resourceURL?.appendingPathComponent("MountMate_MountMateCore.bundle"),
                  let bundle = Bundle(url: url) else {
                fatalError("Missing application language resources")
            }
            return bundle
        }
        return Bundle.module
    }

    private static let catalogs: [AppLanguage: [String: String]] = {
        var result: [AppLanguage: [String: String]] = [:]
        for language in AppLanguage.allCases where language != .system {
            guard let url = resourceBundle.url(forResource: language.rawValue, withExtension: "json"),
                  let data = try? Data(contentsOf: url),
                  let values = try? JSONDecoder().decode([String: String].self, from: data) else {
                continue
            }
            result[language] = values
        }
        return result
    }()

    static func catalog(_ language: AppLanguage) -> [String: String] {
        catalogs[language] ?? [:]
    }

    public static func resolve(_ language: AppLanguage, preferred: [String] = Locale.preferredLanguages) -> AppLanguage {
        guard language == .system else { return language }
        for tag in preferred {
            let parts = tag.lowercased().replacingOccurrences(of: "_", with: "-")
                .split(separator: "-").map(String.init)
            switch parts.first {
            case "zh":
                if parts.contains("hant") { return .traditionalChinese }
                if parts.contains("hans") { return .simplifiedChinese }
                return parts.contains("tw") || parts.contains("hk") || parts.contains("mo")
                    ? .traditionalChinese : .simplifiedChinese
            case "en": return .english
            case "es": return .spanish
            case "fr": return .french
            case "de": return .german
            case "ja": return .japanese
            case "pt": return .portuguese
            default: continue
            }
        }
        return .english
    }

    public static func text(_ key: String, language: AppLanguage, arguments: [String: String] = [:]) -> String {
        let chosen = resolve(language)
        var template = catalog(chosen)[key] ?? catalog(.english)[key] ?? key
        let matches = placeholders.matches(in: template, range: NSRange(template.startIndex..., in: template))
        // Search the original template once. Text inserted by an argument must
        // never be scanned as another placeholder.
        for match in matches.reversed() {
            guard let keyRange = Range(match.range(at: 1), in: template),
                  let valueRange = Range(match.range, in: template),
                  let value = arguments[String(template[keyRange])] else { continue }
            template.replaceSubrange(valueRange, with: value)
        }
        return template
    }

    private static let placeholders = try! NSRegularExpression(pattern: #"\{([a-zA-Z][a-zA-Z0-9_]*)\}"#)
}
