import AppKit
import SwiftUI

// MARK: - Theme

enum AppTheme {
    static let accent = Color(red: 0.27, green: 0.44, blue: 0.84)
    static let logBackground = Color(red: 0.07, green: 0.09, blue: 0.14)
    static let logText = Color(red: 0.52, green: 0.88, blue: 0.60)
    static let uid = Color(red: 0.55, green: 0.34, blue: 0.82)
    static let keyA = Color(red: 0.30, green: 0.70, blue: 0.33)
    static let keyB = Color(red: 0.16, green: 0.60, blue: 0.60)
    static let accessControl = Color(red: 0.90, green: 0.47, blue: 0.18)
}

// MARK: - Buttons

struct ActionButton: View {
    let title: String
    let systemImage: String
    let color: Color
    let isBusy: Bool
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 9) {
                Image(systemName: systemImage)
                    .font(.system(size: 23, weight: .medium))
                    .foregroundStyle(color)
                    .frame(height: 26)
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity, minHeight: 74)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(background)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        Color.primary.opacity(hovering ? 0.18 : 0.06),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .opacity(isBusy ? 0.55 : 1)
        .animation(.easeOut(duration: 0.12), value: hovering)
    }

    private var background: Color {
        if hovering {
            return color.opacity(colorScheme == .dark ? 0.24 : 0.14)
        }
        return colorScheme == .dark
            ? Color.white.opacity(0.06)
            : Color(nsColor: .controlBackgroundColor)
    }
}

struct IconBarButton: View {
    let systemImage: String
    let help: String
    var active = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .medium))
                .frame(width: 28, height: 24)
                .foregroundStyle(active ? Color.accentColor : Color.secondary)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(active ? Color.accentColor.opacity(0.15) : Color.clear)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

// MARK: - Form building blocks

struct SheetTitle: View {
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .multilineTextAlignment(.center)
            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

struct SectionLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct FieldRow: View {
    let label: String
    @Binding var text: String
    var width: CGFloat = 150
    var prompt = ""

    var body: some View {
        HStack(spacing: 12) {
            Text(label)
                .frame(width: 120, alignment: .trailing)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            TextField(prompt, text: $text)
                .textFieldStyle(.roundedBorder)
                .frame(width: width)
            Spacer(minLength: 0)
        }
    }
}

struct KeyTypePicker: View {
    @Binding var selection: String

    var body: some View {
        Picker("", selection: $selection) {
            Text(t("html_key_a")).tag("A")
            Text(t("html_key_b")).tag("B")
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .frame(width: 170)
    }
}

struct SheetButtons: View {
    var confirmTitle: String = t("html_execute")
    let cancel: () -> Void
    let confirm: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Spacer()
            Button(t("dialog_button_cancel"), action: cancel)
                .keyboardShortcut(.cancelAction)
            Button(confirmTitle, action: confirm)
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
        }
    }
}

// MARK: - Validation

enum FieldValidation {
    static func isKey(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.count == 12 && trimmed.allSatisfy(\.isHexDigit)
    }

    static func isSector(_ value: String) -> Bool {
        guard let sector = Int(value.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return false
        }
        return (0...15).contains(sector)
    }

    static func isStartPosition(_ value: String) -> Bool {
        guard let position = Int(value.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return false
        }
        return position >= 0
    }

    static func containsKey(_ value: String) -> Bool {
        value.range(of: "[0-9A-Fa-f]{12}", options: .regularExpression) != nil
    }
}

// MARK: - Hex editor

/// An AppKit-backed editor which colours the UID, key A, access bits and key B
/// of each sector without changing the underlying text. Using NSTextView keeps
/// cursor movement and undo behaviour native while still matching the colours
/// of the original Electron dump editor.
struct HexTextEditor: NSViewRepresentable {
    @Binding var text: String
    var highlightFirstBlock: Bool
    var refreshToken: Int

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, highlightFirstBlock: highlightFirstBlock)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true

        guard let textView = scrollView.documentView as? NSTextView else {
            return scrollView
        }

        let font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.delegate = context.coordinator
        textView.isRichText = true
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.usesFontPanel = false
        textView.usesFindBar = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isAutomaticLinkDetectionEnabled = false
        textView.smartInsertDeleteEnabled = false
        textView.font = font
        textView.textColor = .labelColor
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainerInset = NSSize(width: 8, height: 7)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.lineFragmentPadding = 2
        textView.typingAttributes = [
            .font: font,
            .foregroundColor: NSColor.labelColor
        ]

        textView.string = text
        context.coordinator.textView = textView
        context.coordinator.applyHighlight()

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        context.coordinator.parent = self

        if textView.string != text {
            let selection = textView.selectedRange()
            textView.string = text
            let location = min(selection.location, textView.string.utf16.count)
            textView.setSelectedRange(NSRange(location: location, length: 0))
        }

        context.coordinator.applyHighlight()
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: HexTextEditor
        weak var textView: NSTextView?

        init(text: Binding<String>, highlightFirstBlock: Bool) {
            self.parent = HexTextEditor(
                text: text,
                highlightFirstBlock: highlightFirstBlock,
                refreshToken: 0
            )
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
            applyHighlight()
        }

        func applyHighlight() {
            guard let textView, let storage = textView.textStorage else { return }

            let font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
            let baseAttributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: NSColor.labelColor
            ]

            let dark = textView.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            let uidColor = NSColor.systemPurple
            let keyAColor = dark
                ? NSColor.systemGreen
                : NSColor(calibratedRed: 0.16, green: 0.52, blue: 0.18, alpha: 1)
            let accessColor = NSColor.systemOrange
            let keyBColor = dark
                ? NSColor.systemTeal
                : NSColor(calibratedRed: 0.12, green: 0.45, blue: 0.45, alpha: 1)

            let nsText = storage.string as NSString
            let fullRange = NSRange(location: 0, length: nsText.length)

            storage.beginEditing()
            storage.setAttributes(baseAttributes, range: fullRange)

            var lineStart = 0
            var lineIndex = 0

            while lineStart < nsText.length {
                let searchRange = NSRange(location: lineStart, length: nsText.length - lineStart)
                let newline = nsText.range(of: "\n", options: [], range: searchRange)
                let lineEnd = newline.location == NSNotFound ? nsText.length : newline.location
                let lineRange = NSRange(location: lineStart, length: max(0, lineEnd - lineStart))

                if lineIndex == 3, lineRange.length >= 20 {
                    apply(storage, color: keyAColor, lineStart: lineStart, offset: 0, length: 12, lineLength: lineRange.length)
                    apply(storage, color: accessColor, lineStart: lineStart, offset: 12, length: 6, lineLength: lineRange.length)
                    apply(storage, color: keyBColor, lineStart: lineStart, offset: 20, length: 12, lineLength: lineRange.length)
                } else if lineIndex == 0, parent.highlightFirstBlock, lineRange.length > 0 {
                    apply(storage, color: uidColor, lineStart: lineStart, offset: 0, length: lineRange.length, lineLength: lineRange.length)
                }

                if newline.location == NSNotFound {
                    break
                }
                lineStart = lineEnd + 1
                lineIndex += 1
            }

            storage.endEditing()
            textView.typingAttributes = baseAttributes
        }

        private func apply(
            _ storage: NSTextStorage,
            color: NSColor,
            lineStart: Int,
            offset: Int,
            length: Int,
            lineLength: Int
        ) {
            let start = lineStart + offset
            let available = lineLength - offset
            let safeLength = min(length, max(0, available))
            guard safeLength > 0, start >= 0, start + safeLength <= storage.length else { return }
            storage.addAttribute(
                .foregroundColor,
                value: color,
                range: NSRange(location: start, length: safeLength)
            )
        }
    }
}

// MARK: - Status dot

struct StatusDot: View {
    let indicator: StatusIndicator

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 8, height: 8)
    }

    private var color: Color {
        switch indicator {
        case .none:
            return Color.secondary.opacity(0.25)
        case .running:
            return .green
        case .error:
            return .red
        }
    }
}
