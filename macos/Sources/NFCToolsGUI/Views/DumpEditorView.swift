import AppKit
import SwiftUI

struct DumpEditorView: View {
    @EnvironmentObject private var model: AppModel

    @State private var sectors: [String] = []
    @State private var currentURL: URL?
    @State private var refreshToken = 0
    @State private var didInitialLoad = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            if sectors.isEmpty {
                emptyState
            } else {
                editor
            }

            Divider()
            legend
        }
        .frame(minWidth: 470, minHeight: 660)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear(perform: initialLoad)
        .onChange(of: model.dumpEditorRequest) { _ in
            openRequestedFile()
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "square.and.pencil")
                .foregroundStyle(.secondary)
            Text(currentURL?.lastPathComponent ?? t("html_select_dump"))
                .font(.system(size: 12, weight: .medium))
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()

            Button(t("html_open_file")) {
                chooseFile()
            }
            Button(t("html_save_file")) {
                saveFile()
            }
            .buttonStyle(.borderedProminent)
            .disabled(sectors.isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "doc.badge.plus")
                .font(.system(size: 38, weight: .light))
                .foregroundStyle(.tertiary)
            Text(t("html_dump_editor_empty"))
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            Button(t("html_open_file")) {
                chooseFile()
            }
            .buttonStyle(.borderedProminent)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var editor: some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                ForEach(sectors.indices, id: \.self) { index in
                    VStack(alignment: .leading, spacing: 5) {
                        Text(String(format: t("html_sector_format"), index))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)

                        HexTextEditor(
                            text: $sectors[index],
                            highlightFirstBlock: index == 0,
                            refreshToken: refreshToken
                        )
                        .frame(height: 96)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color(nsColor: .textBackgroundColor).opacity(0.55))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
                        )
                    }
                }
            }
            .padding(16)
        }
        .frame(maxHeight: .infinity)
    }

    private var legend: some View {
        HStack(spacing: 12) {
            legendItem(color: AppTheme.uid, text: t("html_uid_manufacture_info"))
            legendItem(color: AppTheme.keyA, text: t("html_key_a"))
            legendItem(color: AppTheme.keyB, text: t("html_key_b"))
            legendItem(color: AppTheme.accessControl, text: t("html_access_control"))

            Spacer()

            Button(t("html_update_colors")) {
                refreshToken += 1
            }
            .controlSize(.small)
        }
        .font(.system(size: 10))
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func legendItem(color: Color, text: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
            Text(text)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Loading and saving

    private func initialLoad() {
        guard !didInitialLoad else { return }
        didInitialLoad = true
        openRequestedFile()
    }

    private func openRequestedFile() {
        if let url = model.dumpEditorPath {
            load(url)
        } else if sectors.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                chooseFile()
            }
        }
    }

    private func chooseFile() {
        guard let url = model.chooseDumpFile(title: t("dialog_title_choose_dump_file")) else {
            return
        }
        load(url)
    }

    private func load(_ url: URL) {
        do {
            let dump = try model.loadDump(from: url)
            sectors = dump.sectorTexts
            currentURL = url
            refreshToken += 1
        } catch {
            model.showError(t("dialog_title_error"), error.localizedDescription)
        }
    }

    private func saveFile() {
        guard let data = validatedData() else {
            model.showError(t("html_data_format_wrong"), t("dialog_msg_invalid_dump_data"))
            return
        }

        guard let url = currentURL ?? model.chooseDumpSaveFile(
            defaultName: "dump_\(timestamp()).mfd"
        ) else {
            return
        }

        do {
            try data.write(to: url, options: .atomic)
            currentURL = url
            model.showInfo(t("html_save_success"), url.lastPathComponent)
        } catch {
            model.showError(t("dialog_title_error"), error.localizedDescription)
        }
    }

    private func validatedData() -> Data? {
        guard !sectors.isEmpty else { return nil }

        var hex = ""
        for sector in sectors {
            var lines = sector.components(separatedBy: "\n")
            while lines.last?.trimmingCharacters(in: .whitespaces).isEmpty == true {
                lines.removeLast()
            }
            guard lines.count == 4 else { return nil }

            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard trimmed.count == 32, trimmed.allSatisfy(\.isHexDigit) else {
                    return nil
                }
                hex += trimmed
            }
        }

        return DumpData.data(fromHex: hex)
    }

    private func timestamp() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy_MM_dd_HH_mm_ss"
        return formatter.string(from: Date())
    }
}
