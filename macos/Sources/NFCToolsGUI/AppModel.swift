import AppKit
import Combine
import Foundation
import UniformTypeIdentifiers

@MainActor
final class AppModel: ObservableObject {
    static let shared = AppModel()

    // MARK: - Published UI state

    @Published var devices: [String] = []
    @Published var selectedDevice: String?
    @Published var connectionState: ConnectionState = .idle
    @Published var isDeviceConnected = false
    @Published var isRunningTask = false

    @Published var statusText: String = t("indicator_free")
    @Published var statusIndicator: StatusIndicator = .none
    @Published var logText: String = "Hello cardman!"
    @Published var lockScroll = false
    @Published var timerText = ""

    @Published var activeSheet: ActiveSheet?
    @Published var showAbout = false

    @Published var dumps: [String] = []
    @Published var selectedDumps: [String] = []
    @Published var dumpEditorPath: URL?
    @Published var comparatorA: URL?
    @Published var comparatorB: URL?
    @Published var dumpEditorRequest = UUID()
    @Published var comparatorRequest = UUID()

    @Published var dictDisplayName: String = t("html_build_in_dictionary")
    @Published var hardNestedConfig = HardNestedConfig()
    @Published var dictTestConfig = DictTestConfig()
    @Published var inputKeysText = "ffffffffffff,"

    // MARK: - Build information

    let versionText: String
    let builderText: String

    // MARK: - Internal state

    private let runner = ProcessRunner()
    private let fileManager = FileManager.default
    private var timer: Timer?
    private var timerSeconds = 0

    private var dictPath: URL
    private var newKeys: [String] = []
    private var knownKeyInfo: [KnownKey] = []
    private var unknownKeyInfo: [UnknownKey] = []
    private var totalUnknownKeys = 0

    private let defaultKeys = [
        "ffffffffffff",
        "a0a1a2a3a4a5",
        "d3f7d3f7d3f7",
        "000000000000",
        "b0b1b2b3b4b5",
        "4d3a99c351dd",
        "1a982c7e459a",
        "aabbccddeeff",
        "714c5c886e97",
        "587ee5f9350f",
        "a0478cc39091",
        "533cb6c723f6",
        "8fd0a4f256e9"
    ]

    private init() {
        AppPaths.prepare()
        dictPath = AppPaths.dictFile

        let info = Self.loadBuildInfo()
        versionText = info.version
        builderText = info.builder

        scanDevices()
    }

    // MARK: - Device handling

    func displayName(for path: String) -> String {
        for prefix in ["/dev/tty.", "/dev/cu.", "tty.", "cu."] where path.hasPrefix(prefix) {
            return String(path.dropFirst(prefix.count))
        }
        return URL(fileURLWithPath: path).lastPathComponent
    }

    func scanDevices() {
        guard !isRunningTask else { return }

        let names = (try? fileManager.contentsOfDirectory(atPath: "/dev")) ?? []
        var candidates = Set<String>()

        for name in names where name.hasPrefix("tty.") {
            candidates.insert(name)
        }
        for name in names where name.hasPrefix("cu.") {
            let suffix = String(name.dropFirst(3))
            if !candidates.contains("tty." + suffix) {
                candidates.insert(name)
            }
        }

        devices = candidates.sorted().map { "/dev/\($0)" }
    }

    func selectDevice(_ path: String) {
        guard ensureIdle() else { return }

        selectedDevice = path
        connectionState = .connecting
        isDeviceConnected = false

        beginTask()
        printStatus(t("indicator_connecting_device"), .running)

        Task { @MainActor in
            defer { self.endTask() }

            do {
                try self.writeLibtoolConfig(device: path)
                let result = try await self.exec(
                    t("log_msg_start_connect_device"),
                    "nfc-list",
                    [],
                    allowFailure: true
                )

                if result.output.contains("NFC device: NFC_Device opened") {
                    self.isDeviceConnected = true
                    self.connectionState = .connected
                    self.appendLog("\n*** \(t("log_msg_discover_device")) ***\n")
                } else if result.output.contains("Unable to open NFC device") {
                    self.isDeviceConnected = false
                    self.connectionState = .failed
                    self.appendLog("\n*** \(t("log_msg_not_found_device")) ***\n")
                } else {
                    self.isDeviceConnected = false
                    self.connectionState = .failed
                    self.appendLog("\n*** \(t("log_msg_not_found_device")) ***\n")
                }
                self.printExitLog(0)
            } catch is CancellationError {
                self.isDeviceConnected = false
                self.connectionState = .failed
                self.finishCancelled()
            } catch {
                self.isDeviceConnected = false
                self.connectionState = .failed
                self.finishError(error)
            }
        }
    }

    func disconnect() {
        guard ensureIdle() else { return }
        selectedDevice = nil
        isDeviceConnected = false
        connectionState = .idle
    }

    private func writeLibtoolConfig(device: String) throws {
        let content = "device.name = \"NFC_Device\"\ndevice.connstring = \"pn532_uart:\(device):115200\""
        try content.write(to: AppPaths.libnfcConfig, atomically: true, encoding: .utf8)
    }

    // MARK: - Main actions

    func readCard() {
        guard ensureIdle(), ensureConnected() else { return }

        startFlow {
            self.printStatus(t("indicator_reading_ic_card"), .running)
            do {
                try await self.runMFOC(extraKeys: [])
                self.printExitLog(0)
            } catch is CancellationError {
                self.finishCancelled()
            } catch {
                self.finishError(error)
            }
        }
    }

    func writeCard() {
        guard ensureIdle(), ensureConnected() else { return }
        guard let dumpFile = chooseDumpFile(title: t("dialog_title_choose_dump_need_to_write")) else {
            return
        }

        startFlow {
            do {
                try await self.readICThenExec(
                    message: t("log_msg_start_write_card"),
                    statusMessage: t("indicator_writing_ic_card"),
                    isSaveDumpFile: true,
                    command: "nfc-mfclassic",
                    arguments: ["w", "A", "u", dumpFile.path, AppPaths.tempMFD.path, "f"]
                )
                self.printExitLog(0)
            } catch is CancellationError {
                self.finishCancelled()
            } catch {
                self.finishError(error)
            }
        }
    }

    func formatCard() {
        guard ensureIdle(), ensureConnected() else { return }

        startFlow {
            do {
                try await self.readICThenExec(
                    message: t("log_msg_start_format_card"),
                    statusMessage: t("indicator_formatting_ic_card"),
                    isSaveDumpFile: true,
                    command: "nfc-mfclassic",
                    arguments: ["f", "A", "u", AppPaths.tempMFD.path, AppPaths.tempMFD.path, "f"]
                )
                self.printExitLog(0)
            } catch is CancellationError {
                self.finishCancelled()
            } catch {
                self.finishError(error)
            }
        }
    }

    func openInputKeys() {
        guard ensureIdle() else { return }
        inputKeysText = "ffffffffffff,"
        activeSheet = .inputKeys
    }

    func executeInputKeys(_ text: String) {
        guard ensureIdle(), ensureConnected() else { return }
        let keys = matches(of: "[0-9A-Fa-f]{12}", in: text)

        startFlow {
            self.printStatus(t("indicator_reading_ic_card"), .running)
            do {
                try await self.runMFOC(extraKeys: keys)
                self.printExitLog(0)
            } catch is CancellationError {
                self.finishCancelled()
            } catch {
                self.finishError(error)
            }
        }
    }

    func detectCard() {
        guard ensureIdle(), ensureConnected() else { return }

        startFlow {
            self.printStatus(t("indicator_detecting_ic_card"), .running)
            do {
                _ = try await self.runDetection(
                    message: t("log_msg_start_detect_card"),
                    saveDump: false
                )
                self.printExitLog(0)
            } catch is CancellationError {
                self.finishCancelled()
            } catch {
                self.finishError(error)
            }
        }
    }

    func lockUFUID() {
        guard ensureIdle(), ensureConnected() else { return }

        let alert = NSAlert()
        alert.messageText = t("dialog_title_danger_operation")
        alert.informativeText = t("dialog_msg_card_will_be_locked")
        alert.alertStyle = .critical
        alert.addButton(withTitle: t("dialog_button_cancel"))
        alert.addButton(withTitle: t("dialog_button_ok"))
        guard alert.runModal() == .alertSecondButtonReturn else { return }

        startFlow {
            self.printStatus(t("indicator_locking_ufuid"), .running)
            do {
                _ = try await self.exec(t("log_msg_start_lock_ufuid"), "nfc-mflock", ["-q"])
                self.printExitLog(0)
            } catch is CancellationError {
                self.finishCancelled()
            } catch {
                self.finishError(error)
            }
        }
    }

    func stopTask() {
        runner.cancel()
        stopTimer()
        timerText = ""
        statusText = t("indicator_free")
        statusIndicator = .none
    }

    func clearLog() {
        logText = ""
    }

    func saveLog() {
        let defaultName = "NFCTools_log_\(timestamp())"
        guard let url = chooseSaveFile(
            title: t("dialog_title_save_to"),
            defaultName: defaultName,
            extension: "txt",
            allowedExtensions: ["txt"]
        ) else {
            appendLog(t("log_msg_not_saved"))
            return
        }

        do {
            try logText.write(to: url, atomically: true, encoding: .utf8)
            appendLog("\n\n\(t("log_msg_file_already_saved_to")) \(url.path)\n")
        } catch {
            appendLog("\n\(t("log_msh_save_failed"))")
            printExitLog(1)
        }
    }

    // MARK: - HardNested

    func openHardNested() {
        guard ensureIdle() else { return }

        var config = HardNestedConfig()
        if let known = knownKeyInfo.first {
            config.knownKey = known.key
            config.knownSector = String(known.sector)
            config.knownKeyType = known.keyType
        }
        if let target = unknownKeyInfo.first {
            config.targetSector = String(target.sector)
            config.targetKeyType = target.keyType
        }

        hardNestedConfig = config
        activeSheet = .hardNested
    }

    func executeHardNested(_ config: HardNestedConfig) {
        guard ensureIdle(), ensureConnected() else { return }

        var config = config
        config.fromUser = true
        if config.autoRun {
            config.collectOnly = false
        }

        startFlow {
            do {
                if config.autoRun {
                    self.totalUnknownKeys = 0
                    try await self.runAutoHardNested(config)
                } else {
                    _ = try await self.runCollectAndCrack(
                        config,
                        collectOnly: config.collectOnly,
                        showProgress: false
                    )
                }
                self.printExitLog(0)
            } catch is CancellationError {
                self.finishCancelled()
            } catch is FlowAbort {
                self.printExitLog(1)
            } catch {
                self.finishError(error)
            }
        }
    }

    /// The automatic mode re-detects the card before every key, just like the
    /// original implementation, so the known-key list is always current.
    private func runAutoHardNested(_ initial: HardNestedConfig) async throws {
        var config = initial
        config.autoRun = true
        config.collectOnly = false

        try? Data().write(to: AppPaths.noncesFile)

        var firstIteration = true
        while true {
            try throwIfCancelled()

            printStatus(t("indicator_doing_hard_nested") + hardNestedProgress(), .running)
            _ = try await runDetection(
                message: t("lod_msg_start_auto_hard_nested"),
                saveDump: false
            )

            if firstIteration {
                totalUnknownKeys = unknownKeyInfo.count
                firstIteration = false
            }

            guard !knownKeyInfo.isEmpty else {
                appendLog("\n\(t("log_msg_not_found_known_key"))")
                throw FlowAbort()
            }

            guard !unknownKeyInfo.isEmpty else {
                appendLog("\n\(t("log_msg_tried_decrypt_all_unknown_keys"))\n")
                return
            }

            let known = knownKeyInfo[0]
            let target = unknownKeyInfo[0]

            config.knownKey = known.key
            config.knownSector = String(known.sector)
            config.knownKeyType = known.keyType
            config.targetSector = String(target.sector)
            config.targetKeyType = target.keyType

            let madeProgress = try await runCollectAndCrack(
                config,
                collectOnly: false,
                showProgress: true
            )

            // Avoid an endless loop if the cracker reported success without a
            // usable key (for example a partially written nonce file).
            if !madeProgress {
                throw FlowAbort()
            }
        }
    }

    @discardableResult
    private func runCollectAndCrack(
        _ config: HardNestedConfig,
        collectOnly: Bool,
        showProgress: Bool
    ) async throws -> Bool {
        let knownSector = Int(config.knownSector.trimmingCharacters(in: .whitespaces)) ?? 0
        let targetSector = Int(config.targetSector.trimmingCharacters(in: .whitespaces)) ?? 0
        let knownBlock = (knownSector + 1) * 4 - 1
        let targetBlock = (targetSector + 1) * 4 - 1
        let progress = showProgress ? hardNestedProgress() : ""

        printStatus(t("indicator_collecting_nonces") + progress, .running)

        let collectResult = try await exec(
            t("log_msg_start_collect_nonces") + "\n\n",
            "libnfc-collect",
            [
                config.knownKey,
                String(knownBlock),
                config.knownKeyType,
                String(targetBlock),
                config.targetKeyType,
                "bin",
                AppPaths.noncesFile.path
            ]
        )

        let uid = parseUID(collectResult.output) ?? "nonces"
        let collectedSector = parseSector(collectResult.output) ?? targetSector
        let collectedKeyType = parseKeyType(collectResult.output) ?? config.targetKeyType

        if collectOnly {
            if fileSize(AppPaths.noncesFile) > 0 {
                let defaultName = "\(uid)_\(collectedSector)\(collectedKeyType)"
                if let destination = chooseSaveFile(
                    title: t("dialog_title_save_to"),
                    defaultName: defaultName,
                    extension: "bin",
                    allowedExtensions: ["bin"]
                ) {
                    do {
                        if fileManager.fileExists(atPath: destination.path) {
                            try fileManager.removeItem(at: destination)
                        }
                        try fileManager.moveItem(at: AppPaths.noncesFile, to: destination)
                        appendLog("\n\n\(t("log_msg_file_already_saved_to")) \(destination.path)\n")
                    } catch {
                        appendLog("\n\(t("log_msh_save_failed"))")
                        throw error
                    }
                } else {
                    appendLog(t("log_msg_not_saved"))
                }
            }
            return false
        }

        printStatus(t("indicator_doing_hard_nested") + progress, .running)

        let crackResult = try await exec(
            t("lod_msg_start_hard_nested"),
            "cropto1_bs",
            [AppPaths.noncesFile.path]
        )

        guard let key = parseFoundKey(crackResult.output) else {
            return false
        }

        saveKeys([key])

        if let first = unknownKeyInfo.first,
           first.sector == targetSector,
           first.keyType == config.targetKeyType {
            unknownKeyInfo.removeFirst()
            return true
        }

        return false
    }

    private func hardNestedProgress() -> String {
        guard totalUnknownKeys > 0 else { return "" }
        let current = min(totalUnknownKeys, totalUnknownKeys - unknownKeyInfo.count + 1)
        return " - \(current)/\(totalUnknownKeys)"
    }

    // MARK: - Dictionary testing

    func openDictTest() {
        guard ensureIdle() else { return }

        var config = DictTestConfig()
        if let target = unknownKeyInfo.first {
            config.sector = String(target.sector)
            config.keyType = target.keyType
        }
        dictTestConfig = config
        activeSheet = .dictTest
    }

    func chooseDictionaryFile() {
        guard let url = chooseOpenFile(
            title: t("dialog_title_choose_dictionary_file"),
            extensions: ["txt", "dic"],
            directory: nil
        ) else {
            return
        }
        dictPath = url
        dictDisplayName = url.lastPathComponent
    }

    func executeDictTest(_ config: DictTestConfig) {
        guard ensureIdle(), ensureConnected() else { return }

        startFlow {
            self.printStatus(t("indicator_testing_dictionary"), .running)
            do {
                let result = try await self.exec(
                    t("log_msg_start_test_dictionary"),
                    "nfc-mfdict",
                    [
                        "-s\(config.sector)",
                        "-t\(config.keyType)",
                        "-l\(config.startPosition)",
                        "-d\(self.dictPath.path)"
                    ]
                )

                if let key = self.parseFoundKey(result.output) {
                    self.saveKeys([key])
                    if let first = self.unknownKeyInfo.first,
                       String(first.sector) == config.sector,
                       first.keyType == config.keyType {
                        self.unknownKeyInfo.removeFirst()
                    }
                }

                self.printExitLog(0)
            } catch is CancellationError {
                self.finishCancelled()
            } catch {
                self.finishError(error)
            }
        }
    }

    // MARK: - History keys

    func openHistoricalKeys() {
        checkKeyFileExist()
        NSWorkspace.shared.open(AppPaths.keysFile)
    }

    // MARK: - Dump files

    func refreshDumps() {
        try? fileManager.createDirectory(at: AppPaths.dumpsDirectory, withIntermediateDirectories: true)

        let files = (try? fileManager.contentsOfDirectory(
            at: AppPaths.dumpsDirectory,
            includingPropertiesForKeys: nil
        ))?
            .filter { $0.pathExtension.lowercased() == "mfd" }
            .map { $0.lastPathComponent }
            .sorted() ?? []

        dumps = files
        selectedDumps.removeAll { !files.contains($0) }
    }

    func toggleDumpSelection(_ name: String) {
        if let index = selectedDumps.firstIndex(of: name) {
            selectedDumps.remove(at: index)
        } else {
            selectedDumps.append(name)
        }
    }

    func renameDump(oldName: String, newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != oldName else {
            refreshDumps()
            return
        }

        let source = AppPaths.dumpsDirectory.appendingPathComponent(oldName)
        let destination = AppPaths.dumpsDirectory.appendingPathComponent(trimmed)

        guard !fileManager.fileExists(atPath: destination.path) else {
            showError(t("dialog_title_error"), trimmed)
            refreshDumps()
            return
        }

        do {
            try fileManager.moveItem(at: source, to: destination)
            refreshDumps()
        } catch {
            showError(t("dialog_title_error"), error.localizedDescription)
            refreshDumps()
        }
    }

    func deleteDumps(_ names: [String]) {
        let names = names.filter { !$0.isEmpty }
        guard !names.isEmpty else { return }

        let alert = NSAlert()
        alert.messageText = t("dialog_title_prompt")
        alert.informativeText = t("dialog_msg_are_you_sure_to_delete_these_dumps")
            + "\n\n" + names.joined(separator: "\n")
        alert.alertStyle = .warning
        alert.addButton(withTitle: t("dialog_button_ok"))
        alert.addButton(withTitle: t("dialog_button_cancel"))
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        for name in names {
            try? fileManager.removeItem(at: AppPaths.dumpsDirectory.appendingPathComponent(name))
        }
        selectedDumps.removeAll { names.contains($0) }
        refreshDumps()
    }

    func dumpURL(for name: String) -> URL {
        AppPaths.dumpsDirectory.appendingPathComponent(name)
    }

    func prepareDumpEditor(file: URL?) {
        dumpEditorPath = file
        dumpEditorRequest = UUID()
    }

    func prepareComparator(a: URL?, b: URL?) {
        comparatorA = a
        comparatorB = b
        comparatorRequest = UUID()
    }

    func chooseDumpFile(title: String, directory: URL? = nil) -> URL? {
        chooseOpenFile(
            title: title,
            extensions: ["mfd", "dump"],
            directory: directory ?? AppPaths.dumpsDirectory
        )
    }

    func loadDump(from url: URL) throws -> DumpData {
        DumpData(data: try Data(contentsOf: url))
    }

    func chooseDumpSaveFile(defaultName: String) -> URL? {
        let base = defaultName.lowercased().hasSuffix(".mfd")
            ? String(defaultName.dropLast(4))
            : defaultName
        return chooseSaveFile(
            title: t("dialog_title_save_to"),
            defaultName: base,
            extension: "mfd",
            allowedExtensions: ["mfd", "dump"]
        )
    }

    // MARK: - Alerts

    func showError(_ title: String, _ message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: t("dialog_button_ok"))
        alert.runModal()
    }

    func showInfo(_ title: String, _ message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: t("dialog_button_ok"))
        alert.runModal()
    }

    func confirmExitIfNeeded() -> Bool {
        guard isRunningTask else { return true }

        let alert = NSAlert()
        alert.messageText = t("dialog_title_prompt")
        alert.informativeText = t("dialog_msg_are_you_sure_to_exit")
        alert.alertStyle = .warning
        alert.addButton(withTitle: t("dialog_button_cancel"))
        alert.addButton(withTitle: t("dialog_button_still_exit"))
        guard alert.runModal() == .alertSecondButtonReturn else { return false }
        runner.cancel()
        return true
    }

    // MARK: - Task lifecycle and log

    private func startFlow(_ body: @escaping @MainActor () async -> Void) {
        beginTask()
        Task { @MainActor in
            await body()
            self.endTask()
        }
    }

    private func beginTask() {
        runner.resetCancellation()
        isRunningTask = true
    }

    private func endTask() {
        isRunningTask = false
    }

    private func throwIfCancelled() throws {
        if runner.isCancelled {
            throw CancellationError()
        }
    }

    private func appendLog(_ text: String) {
        var value = text
        if value.contains("\u{1b}[2K") {
            if let lastNewline = logText.lastIndex(of: "\n") {
                logText = String(logText[..<lastNewline])
            }
            value = value.replacingOccurrences(of: "\u{1b}[2K", with: "")
        }
        logText += value
    }

    private func printStatus(_ text: String, _ indicator: StatusIndicator) {
        statusText = text
        statusIndicator = indicator

        switch indicator {
        case .running:
            startTimerIfNeeded()
        case .none, .error:
            stopTimer()
        }
    }

    private func printExitLog(_ code: Int) {
        switch code {
        case 0:
            printStatus(t("indicator_free"), .none)
            appendLog("\n\(t("log_msg_finished"))")
        case 1:
            printStatus(t("indicator_error"), .error)
            appendLog("\n\(t("log_msg_error"))")
        case 2:
            printStatus(t("indicator_free"), .none)
            appendLog("\n\(t("log_msg_finished"))")
        default:
            break
        }
    }

    private func finishError(_ error: Error) {
        if let nfcError = error as? NFCError {
            appendLog("\n\(nfcError.localizedDescription)")
        } else if !(error is CancellationError) {
            appendLog("\n\(error.localizedDescription)")
        }
        printExitLog(1)
    }

    private func finishCancelled() {
        printExitLog(2)
    }

    private func startTimerIfNeeded() {
        guard timer == nil else { return }
        timerSeconds = 0
        timerText = "00:00:00"

        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.timerTick()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func timerTick() {
        timerSeconds += 1
        let hours = timerSeconds / 3600
        let minutes = (timerSeconds / 60) % 60
        let seconds = timerSeconds % 60
        timerText = String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Tool chain

    @discardableResult
    private func exec(
        _ message: String,
        _ command: String,
        _ arguments: [String],
        allowFailure: Bool = false
    ) async throws -> CommandResult {
        if command == "nfc-list" {
            guard selectedDevice != nil else {
                throw NFCError.notConnected
            }
        } else {
            guard selectedDevice != nil, isDeviceConnected else {
                throw NFCError.notConnected
            }
        }

        appendLog("\n\n### \(message)\n")

        let result = try await runner.run(
            command,
            arguments: arguments,
            environment: ["LIBNFC_SYSCONFDIR": AppPaths.appSupport.path]
        ) { [weak self] chunk in
            self?.appendLog(chunk)
        }

        if result.exitCode != 0 {
            appendLog("\nexit code: \(result.exitCode)")
            if !allowFailure {
                throw NFCError.exitCode(result.exitCode)
            }
        }

        return result
    }

    private func runDetection(message: String, saveDump: Bool) async throws -> CommandResult {
        checkKeyFileExist()
        newKeys = []
        knownKeyInfo = []
        unknownKeyInfo = []

        let arguments = saveDump
            ? ["-O\(AppPaths.tempMFD.path)", "-f\(AppPaths.keysFile.path)"]
            : ["-N", "-f\(AppPaths.keysFile.path)"]

        let result = try await exec(message, "nfc-mfdetect", arguments)
        processKeyInfo(result.output)
        saveKeys(newKeys)
        return result
    }

    private func readICThenExec(
        message: String,
        statusMessage: String,
        isSaveDumpFile: Bool,
        command: String,
        arguments: [String]
    ) async throws {
        printStatus(t("indicator_detecting_ic_card"), .running)
        _ = try await runDetection(
            message: t("log_msg_read_ic_then_execute"),
            saveDump: isSaveDumpFile
        )

        if isSaveDumpFile, fileSize(AppPaths.tempMFD) == 0 {
            try? fileManager.removeItem(at: AppPaths.tempMFD)
        }

        printStatus(statusMessage, .running)

        if isSaveDumpFile, !fileManager.fileExists(atPath: AppPaths.tempMFD.path) {
            return
        }

        _ = try await exec(message, command, arguments)
        try? fileManager.removeItem(at: AppPaths.tempMFD)
    }

    private func runMFOC(extraKeys: [String]) async throws {
        newKeys = []
        knownKeyInfo = []
        unknownKeyInfo = []
        checkKeyFileExist()

        let keyArguments = extraKeys.map { "-k\($0)" }
        let arguments = keyArguments + [
            "-O\(AppPaths.tempMFD.path)",
            "-f\(AppPaths.keysFile.path)"
        ]

        let result = try await exec(t("log_msg_start_mfoc"), "mfoc", arguments)
        processKeyInfo(result.output)
        saveKeys(newKeys)

        if fileSize(AppPaths.tempMFD) == 0 {
            try? fileManager.removeItem(at: AppPaths.tempMFD)
            return
        }

        try? fileManager.createDirectory(at: AppPaths.dumpsDirectory, withIntermediateDirectories: true)

        let cardID = parseUID(result.output) ?? "unknown"
        var destination = AppPaths.dumpsDirectory
            .appendingPathComponent("\(cardID)_\(timestamp()).mfd")

        if fileManager.fileExists(atPath: destination.path) {
            destination = AppPaths.dumpsDirectory
                .appendingPathComponent("\(cardID)_\(timestamp())_2.mfd")
        }

        do {
            try fileManager.moveItem(at: AppPaths.tempMFD, to: destination)
            refreshDumps()
        } catch {
            appendLog("\n\(error.localizedDescription)")
        }
    }

    // MARK: - Key file handling

    private func checkKeyFileExist() {
        try? fileManager.createDirectory(at: AppPaths.appSupport, withIntermediateDirectories: true)
        if !fileManager.fileExists(atPath: AppPaths.keysFile.path) {
            fileManager.createFile(atPath: AppPaths.keysFile.path, contents: Data())
        }
    }

    private func processKeyInfo(_ output: String) {
        guard let regex = try? NSRegularExpression(
            pattern: "(Found|Unknown)\\s+Key\\s+([AB])(?::\\s*([0-9A-Fa-f]{12}))?",
            options: [.caseInsensitive]
        ) else {
            return
        }

        let nsOutput = output as NSString
        let matches = regex.matches(in: output, range: NSRange(location: 0, length: nsOutput.length))

        for (index, match) in matches.enumerated() {
            let sector = index / 2
            let status = nsOutput.substring(with: match.range(at: 1)).lowercased()
            let keyType = nsOutput.substring(with: match.range(at: 2)).uppercased()

            if status.hasPrefix("f") {
                guard match.range(at: 3).location != NSNotFound else { continue }
                let key = nsOutput.substring(with: match.range(at: 3)).lowercased()
                knownKeyInfo.append(KnownKey(key: key, sector: sector, keyType: keyType))
                newKeys.append(key)
            } else {
                unknownKeyInfo.append(UnknownKey(sector: sector, keyType: keyType))
            }
        }
    }

    private func saveKeys(_ keys: [String]) {
        checkKeyFileExist()

        let existing = (try? String(contentsOf: AppPaths.keysFile, encoding: .utf8)) ?? ""
        let candidates = matches(of: "[0-9A-Fa-f]{12}", in: existing) + keys.map { $0.lowercased() }

        var ordered: [String] = []
        var seen = Set<String>()
        for key in candidates {
            let lower = key.lowercased()
            guard !seen.contains(lower) else { continue }
            seen.insert(lower)
            ordered.append(lower)
        }

        let filtered = ordered.filter { !defaultKeys.contains($0) }
        try? filtered.joined(separator: "\n").write(
            to: AppPaths.keysFile,
            atomically: true,
            encoding: .utf8
        )
    }

    // MARK: - Output parsing

    private func parseUID(_ output: String) -> String? {
        for line in output.components(separatedBy: .newlines) {
            guard let range = line.range(of: "UID (NFCID1):") else { continue }
            let tail = String(line[range.upperBound...])
            let pairs = matches(of: "[0-9A-Fa-f]{2}", in: tail)
            if !pairs.isEmpty {
                return String(pairs.joined().prefix(14)).lowercased()
            }
        }
        return nil
    }

    private func parseSector(_ output: String) -> Int? {
        guard let regex = try? NSRegularExpression(pattern: "\\(sector (\\d{1,2})\\)") else {
            return nil
        }
        let nsOutput = output as NSString
        guard let match = regex.firstMatch(
            in: output,
            range: NSRange(location: 0, length: nsOutput.length)
        ), match.numberOfRanges > 1 else {
            return nil
        }
        return Int(nsOutput.substring(with: match.range(at: 1)))
    }

    private func parseKeyType(_ output: String) -> String? {
        guard let range = output.range(of: "collecting nonces for key") else {
            return nil
        }
        let tail = output[range.upperBound...]
        if let character = tail.first(where: { $0 == "A" || $0 == "B" }) {
            return String(character)
        }
        return nil
    }

    private func parseFoundKey(_ output: String) -> String? {
        let patterns = [
            "Key found:\\s*([0-9A-Fa-f]{12})",
            "Found Key:\\s*([0-9A-Fa-f]{12})"
        ]

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let nsOutput = output as NSString
            guard let match = regex.firstMatch(
                in: output,
                range: NSRange(location: 0, length: nsOutput.length)
            ), match.numberOfRanges > 1 else {
                continue
            }
            return nsOutput.substring(with: match.range(at: 1)).lowercased()
        }
        return nil
    }

    private func matches(of pattern: String, in text: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return []
        }
        let nsText = text as NSString
        return regex.matches(in: text, range: NSRange(location: 0, length: nsText.length)).map {
            nsText.substring(with: $0.range)
        }
    }

    // MARK: - File panels and helpers

    private func chooseOpenFile(
        title: String,
        extensions: [String],
        directory: URL?
    ) -> URL? {
        let panel = NSOpenPanel()
        panel.title = title
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        if let directory {
            panel.directoryURL = directory
        }

        let types = extensions.compactMap { UTType(filenameExtension: $0) }
        if !types.isEmpty {
            panel.allowedContentTypes = types
        }

        return panel.runModal() == .OK ? panel.url : nil
    }

    private func chooseSaveFile(
        title: String,
        defaultName: String,
        extension fileExtension: String,
        allowedExtensions: [String]
    ) -> URL? {
        let panel = NSSavePanel()
        panel.title = title
        panel.nameFieldStringValue = "\(defaultName).\(fileExtension)"
        panel.canCreateDirectories = true

        let types = allowedExtensions.compactMap { UTType(filenameExtension: $0) }
        if !types.isEmpty {
            panel.allowedContentTypes = types
        }

        return panel.runModal() == .OK ? panel.url : nil
    }

    private func fileSize(_ url: URL) -> Int64 {
        guard let attributes = try? fileManager.attributesOfItem(atPath: url.path),
              let size = attributes[.size] as? NSNumber else {
            return 0
        }
        return size.int64Value
    }

    private func timestamp() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy_MM_dd_HH_mm_ss"
        return formatter.string(from: Date())
    }

    private func ensureIdle() -> Bool {
        guard !isRunningTask else {
            showError(t("dialog_title_device_busy"), t("dialog_msg_running_task"))
            return false
        }
        return true
    }

    private func ensureConnected() -> Bool {
        guard selectedDevice != nil, isDeviceConnected else {
            printStatus(t("indicator_error"), .error)
            showError(t("dialog_title_error"), t("dialog_msg_not_connected_device"))
            return false
        }
        return true
    }

    private static func loadBuildInfo() -> (version: String, builder: String) {
        let shortVersion = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "2.0.0"
        var version = shortVersion.hasPrefix("v") ? shortVersion : "v\(shortVersion)"
        var builder = (Bundle.main.infoDictionary?["NFCToolsGUIBuilder"] as? String)
            ?? "Native SwiftUI (arm64)"

        let url = AppPaths.resources.appendingPathComponent("BuildInfo.txt")
        if let text = try? String(contentsOf: url, encoding: .utf8) {
            for line in text.split(separator: "\n") {
                let parts = line.split(separator: "=", maxSplits: 1).map(String.init)
                guard parts.count == 2 else { continue }
                switch parts[0] {
                case "version":
                    version = parts[1]
                case "builder":
                    builder = parts[1]
                case "commit":
                    if !parts[1].isEmpty {
                        builder += " (\(parts[1]))"
                    }
                default:
                    break
                }
            }
        }

        return (version, builder)
    }
}
