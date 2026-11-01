import Darwin
import Foundation

private final class OutputBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var data = Data()

    func append(_ chunk: Data) {
        lock.lock()
        data.append(chunk)
        lock.unlock()
    }

    var string: String {
        lock.lock()
        defer { lock.unlock() }
        return String(decoding: data, as: UTF8.self)
    }
}

/// Runs one bundled CLI tool at a time, streams its output to the UI and
/// supports cooperative cancellation from the Stop button.
final class ProcessRunner: @unchecked Sendable {
    private let lock = NSLock()
    private var process: Process?
    private var cancelRequested = false

    var isCancelled: Bool {
        locked { cancelRequested }
    }

    private func locked<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }

    func resetCancellation() {
        locked { cancelRequested = false }
    }

    func cancel() {
        let runningProcess: Process? = locked {
            cancelRequested = true
            return process
        }

        guard let runningProcess, runningProcess.isRunning else { return }
        runningProcess.terminate()

        let pid = runningProcess.processIdentifier
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 1.5) {
            if runningProcess.isRunning {
                kill(pid, SIGKILL)
            }
        }
    }

    func run(
        _ command: String,
        arguments: [String],
        environment: [String: String] = [:],
        onOutput: (@MainActor @Sendable (String) -> Void)? = nil
    ) async throws -> CommandResult {
        if isCancelled {
            throw CancellationError()
        }

        let executable = AppPaths.binDirectory.appendingPathComponent(command)
        guard FileManager.default.isExecutableFile(atPath: executable.path) else {
            throw NFCError.missingBinary(command)
        }

        let child = Process()
        child.executableURL = executable
        child.arguments = arguments
        child.standardInput = FileHandle.nullDevice
        child.environment = ProcessInfo.processInfo.environment.merging(environment) { _, new in new }

        let stdout = Pipe()
        let stderr = Pipe()
        child.standardOutput = stdout
        child.standardError = stderr

        let buffer = OutputBuffer()
        let readers = DispatchGroup()

        func startReader(_ handle: FileHandle) {
            readers.enter()
            DispatchQueue.global(qos: .userInitiated).async {
                while true {
                    let data = handle.availableData
                    if data.isEmpty {
                        break
                    }
                    buffer.append(data)
                    if let text = String(data: data, encoding: .utf8), !text.isEmpty {
                        Task { @MainActor in
                            onOutput?(text)
                        }
                    }
                }
                readers.leave()
            }
        }

        startReader(stdout.fileHandleForReading)
        startReader(stderr.fileHandleForReading)

        do {
            try child.run()
        } catch {
            // Unblock the reader threads if the process could not start.
            try? stdout.fileHandleForWriting.close()
            try? stderr.fileHandleForWriting.close()
            throw error
        }

        let shouldCancel = locked { () -> Bool in
            process = child
            return cancelRequested
        }
        if shouldCancel {
            child.terminate()
        }

        let exitCode: Int32 = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                child.waitUntilExit()
                continuation.resume(returning: child.terminationStatus)
            }
        }

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            readers.notify(queue: .global(qos: .userInitiated)) {
                continuation.resume()
            }
        }

        locked {
            if process === child {
                process = nil
            }
        }

        if isCancelled {
            throw CancellationError()
        }

        return CommandResult(exitCode: exitCode, output: buffer.string, cancelled: false)
    }
}
