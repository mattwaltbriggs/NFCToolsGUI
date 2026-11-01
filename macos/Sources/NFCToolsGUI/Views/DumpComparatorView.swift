import SwiftUI

struct DumpComparatorView: View {
    @EnvironmentObject private var model: AppModel

    @State private var dumpA: DumpData?
    @State private var dumpB: DumpData?
    @State private var nameA: String?
    @State private var nameB: String?
    @State private var didInitialLoad = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            if dumpA == nil || dumpB == nil {
                emptyState
            } else {
                comparison
            }

            Divider()
            footer
        }
        .frame(minWidth: 560, minHeight: 660)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear(perform: initialLoad)
        .onChange(of: model.comparatorRequest) { _ in
            loadRequestedFiles()
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            fileButton(
                title: t("html_dump_a"),
                name: nameA,
                color: .blue
            ) {
                chooseFile(side: .a)
            }

            fileButton(
                title: t("html_dump_b"),
                name: nameB,
                color: .purple
            ) {
                chooseFile(side: .b)
            }
        }
        .padding(16)
    }

    private func fileButton(
        title: String,
        name: String?,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "doc")
                    .foregroundStyle(color)
                Text(title)
                    .fontWeight(.medium)
                Text(name ?? t("html_choose_file"))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer(minLength: 0)
                Image(systemName: "ellipsis.circle")
                    .foregroundStyle(.secondary)
            }
            .font(.system(size: 12))
            .padding(.horizontal, 12)
            .frame(height: 34)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "rectangle.split.2x1")
                .font(.system(size: 38, weight: .light))
                .foregroundStyle(.tertiary)
            Text(t("html_dump_comparator_empty"))
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var comparison: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                ForEach(sectorIndices, id: \.self) { sector in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(String(format: t("html_sector_format"), sector))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)

                        ForEach(0..<4, id: \.self) { row in
                            let block = sector * 4 + row
                            VStack(alignment: .leading, spacing: 3) {
                                rowView(
                                    prefix: "A",
                                    text: text(for: dumpA, block: block),
                                    other: text(for: dumpB, block: block),
                                    color: .blue
                                )
                                rowView(
                                    prefix: "B",
                                    text: text(for: dumpB, block: block),
                                    other: text(for: dumpA, block: block),
                                    color: .purple
                                )
                            }
                            if row < 3 {
                                Divider()
                                    .opacity(0.4)
                            }
                        }
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.primary.opacity(0.035))
                    )
                }
            }
            .padding(16)
        }
        .frame(maxHeight: .infinity)
    }

    private func rowView(
        prefix: String,
        text: String?,
        other: String?,
        color: Color
    ) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(prefix + ":")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(color)
                .frame(width: 18, alignment: .leading)
            Text(highlighted(text, against: other))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color.red.opacity(0.7))
                .frame(width: 7, height: 7)
            Text(t("html_differences_highlighted"))
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
    }

    // MARK: - Data

    private var sectorIndices: [Int] {
        let blocks = max(dumpA?.blocks.count ?? 0, dumpB?.blocks.count ?? 0)
        let sectors = max(16, (blocks + 3) / 4)
        return Array(0..<sectors)
    }

    private func text(for dump: DumpData?, block: Int) -> String? {
        guard let dump, block < dump.blocks.count else { return nil }
        return dump.blocks[block]
    }

    private func highlighted(_ text: String?, against other: String?) -> AttributedString {
        guard let text, !text.isEmpty else {
            var missing = AttributedString(t("html_missing_dump"))
            missing.font = .system(size: 11, design: .monospaced)
            missing.foregroundColor = .red
            return missing
        }

        var attributed = AttributedString(text)
        attributed.font = .system(size: 11, design: .monospaced)

        guard let other, !other.isEmpty else {
            attributed.foregroundColor = .red
            return attributed
        }

        let lhs = Array(text)
        let rhs = Array(other)
        for index in lhs.indices where index >= rhs.count || lhs[index] != rhs[index] {
            let start = attributed.characters.index(attributed.startIndex, offsetBy: index)
            let end = attributed.characters.index(after: start)
            attributed[start..<end].foregroundColor = .red
            attributed[start..<end].backgroundColor = Color.red.opacity(0.16)
        }

        return attributed
    }

    // MARK: - Loading

    private func initialLoad() {
        guard !didInitialLoad else { return }
        didInitialLoad = true
        loadRequestedFiles()
    }

    private func loadRequestedFiles() {
        if let url = model.comparatorA {
            load(url, side: .a)
        }
        if let url = model.comparatorB {
            load(url, side: .b)
        }
    }

    private func chooseFile(side: Side) {
        guard let url = model.chooseDumpFile(title: t("dialog_title_choose_dump_file")) else {
            return
        }
        load(url, side: side)
    }

    private func load(_ url: URL, side: Side) {
        do {
            let dump = try model.loadDump(from: url)
            switch side {
            case .a:
                dumpA = dump
                nameA = url.lastPathComponent
            case .b:
                dumpB = dump
                nameB = url.lastPathComponent
            }
        } catch {
            model.showError(t("dialog_title_error"), error.localizedDescription)
        }
    }

    private enum Side {
        case a
        case b
    }
}
