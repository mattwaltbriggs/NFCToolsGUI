import Foundation

/// Locations used by both the native app and the bundled command line tools.
///
/// The user data directory intentionally matches the old Electron build so
/// existing keys.txt, dumps and libnfc.conf files keep working.
enum AppPaths {
    static let appSupport: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Application Support", isDirectory: true)
        return base.appendingPathComponent("NFCToolsGUI", isDirectory: true)
    }()

    static let keysFile = appSupport.appendingPathComponent("keys.txt")
    static let tempMFD = appSupport.appendingPathComponent("temp.mfd")
    static let dumpsDirectory = appSupport.appendingPathComponent("dumpfiles", isDirectory: true)
    static let noncesFile = appSupport.appendingPathComponent("nonces.bin")
    static let libnfcConfig = appSupport.appendingPathComponent("libnfc.conf")

    /// When running from the assembled .app this is Contents/Resources.
    /// When running through `swift run`, fall back to the repository root.
    static let resources: URL = {
        if let resourceURL = Bundle.main.resourceURL,
           FileManager.default.fileExists(atPath: resourceURL.appendingPathComponent("dict.dic").path) {
            return resourceURL
        }

        let sourceFile = URL(fileURLWithPath: #filePath)
        return sourceFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }()

    static var binDirectory: URL {
        resources.appendingPathComponent("framework/bin", isDirectory: true)
    }

    static var dictFile: URL {
        resources.appendingPathComponent("dict.dic")
    }

    static var localesDirectory: URL {
        let bundled = resources.appendingPathComponent("locales", isDirectory: true)
        if FileManager.default.fileExists(atPath: bundled.path) {
            return bundled
        }
        // `swift run` executes from the repository checkout, where the locale
        // files still live under src/locales.
        return resources.appendingPathComponent("src/locales", isDirectory: true)
    }

    static func prepare() {
        let fileManager = FileManager.default
        try? fileManager.createDirectory(at: appSupport, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: dumpsDirectory, withIntermediateDirectories: true)
        if !fileManager.fileExists(atPath: keysFile.path) {
            fileManager.createFile(atPath: keysFile.path, contents: Data())
        }
    }
}
