import Foundation

enum StatusIndicator {
    case none
    case running
    case error
}

enum ConnectionState {
    case idle
    case connecting
    case connected
    case failed
}

enum ActiveSheet: String, Identifiable {
    case inputKeys
    case hardNested
    case dictTest

    var id: String { rawValue }
}

struct KnownKey {
    let key: String
    let sector: Int
    let keyType: String
}

struct UnknownKey {
    let sector: Int
    let keyType: String
}

struct HardNestedConfig {
    var knownKey = "ffffffffffff"
    var knownSector = "0"
    var knownKeyType = "A"
    var targetSector = "0"
    var targetKeyType = "A"
    var collectOnly = false
    var autoRun = false
    var fromUser = false
}

struct DictTestConfig {
    var sector = "0"
    var keyType = "A"
    var startPosition = "0"
}

enum NFCError: LocalizedError {
    case notConnected
    case missingBinary(String)
    case exitCode(Int32)
    case message(String)

    var errorDescription: String? {
        switch self {
        case .notConnected:
            return t("dialog_msg_not_connected_device")
        case .missingBinary(let name):
            return "Missing bundled command line tool: \(name)"
        case .exitCode(let code):
            return "exit code: \(code)"
        case .message(let message):
            return message
        }
    }
}

/// Raised when a flow has already printed its own diagnostic and only needs
/// the standard error footer.
struct FlowAbort: Error {}

struct CommandResult {
    let exitCode: Int32
    let output: String
    let cancelled: Bool
}

/// A 1024-byte MIFARE Classic 1K dump, split into 32-character blocks.
/// If a file is shorter or longer than expected, blocks are padded to whole
/// sectors so the editor can still display it as four lines per sector.
struct DumpData {
    static let blockLength = 32
    static let emptyBlock = String(repeating: "0", count: blockLength)

    var blocks: [String]

    init(data: Data) {
        let bytes = [UInt8](data)
        var parsed: [String] = []

        var offset = 0
        while offset < bytes.count {
            let end = min(offset + 16, bytes.count)
            var block = bytes[offset..<end].map { String(format: "%02x", $0) }.joined()
            if block.count < Self.blockLength {
                block += String(repeating: "0", count: Self.blockLength - block.count)
            }
            parsed.append(block)
            offset += 16
        }

        while parsed.count % 4 != 0 {
            parsed.append(Self.emptyBlock)
        }
        if parsed.isEmpty {
            parsed = Array(repeating: Self.emptyBlock, count: 64)
        }
        blocks = parsed
    }

    init(blocks: [String]) {
        self.blocks = blocks
    }

    var sectorTexts: [String] {
        stride(from: 0, to: blocks.count, by: 4).map { start in
            let end = min(start + 4, blocks.count)
            return blocks[start..<end].joined(separator: "\n")
        }
    }

    static func data(fromHex hex: String) -> Data? {
        let clean = hex.filter { !$0.isWhitespace }
        guard !clean.isEmpty,
              clean.count % 2 == 0,
              clean.allSatisfy({ $0.isHexDigit }) else {
            return nil
        }

        var data = Data(capacity: clean.count / 2)
        var index = clean.startIndex
        while index < clean.endIndex {
            let next = clean.index(index, offsetBy: 2)
            guard let byte = UInt8(clean[index..<next], radix: 16) else {
                return nil
            }
            data.append(byte)
            index = next
        }
        return data
    }
}
