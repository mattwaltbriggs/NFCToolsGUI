import Foundation

/// Small JSON-backed localiser. It uses the same keys and files as the
/// original application so translations stay in sync.
final class L10n {
    static let shared = L10n()

    private var texts: [String: String] = [:]
    let language: String

    private init() {
        language = Self.preferredLanguage()
        load(language: language)
    }

    private static func preferredLanguage() -> String {
        for identifier in Locale.preferredLanguages {
            let lower = identifier.lowercased()
            if lower.hasPrefix("zh") {
                return "zh-CN"
            }
            if lower.hasPrefix("en") {
                return "en"
            }
        }
        return "en"
    }

    private func load(language: String) {
        if loadFile(language) {
            return
        }
        if language != "en" {
            _ = loadFile("en")
        }
    }

    @discardableResult
    private func loadFile(_ language: String) -> Bool {
        let url = AppPaths.localesDirectory.appendingPathComponent("\(language).json")
        guard let data = try? Data(contentsOf: url),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: String] else {
            return false
        }
        texts = object
        return true
    }

    func tr(_ key: String) -> String {
        texts[key] ?? key
    }
}

func t(_ key: String) -> String {
    L10n.shared.tr(key)
}
