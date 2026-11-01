import SwiftUI

struct DumpHistoryView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.openWindow) private var openWindow

    @State private var selected: Set<String> = []
    @State private var hovered: String?
    @State private var renameTarget: String?
    @State private var renameText = ""
    @State private var showRename = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            if model.dumps.isEmpty {
                emptyState
            } else {
                list
            }

            Divider()
            bottomBar
        }
        .frame(minWidth: 420, minHeight: 560)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            model.refreshDumps()
        }
        .onReceive(model.$dumps) { dumps in
            selected.formIntersection(Set(dumps))
        }
        .alert(t("html_rename"), isPresented: $showRename) {
            TextField(t("html_rename"), text: $renameText)
            Button(t("dialog_button_cancel"), role: .cancel) {
                renameTarget = nil
            }
            Button(t("dialog_button_ok")) {
                if let target = renameTarget {
                    model.renameDump(oldName: target, newName: renameText)
                }
                renameTarget = nil
                selected.removeAll()
            }
        } message: {
            Text(renameTarget ?? "")
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "clock.arrow.circlepath")
                .foregroundStyle(.secondary)
            Text(t("html_dump_history"))
                .font(.system(size: 13, weight: .semibold))
            Spacer()
            Text("\(model.dumps.count)")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Capsule().fill(Color.primary.opacity(0.08)))
            Button {
                model.refreshDumps()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.plain)
            .help(t("html_refresh"))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "tray")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(.tertiary)
            Text(t("html_no_dumps"))
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: 6) {
                ForEach(model.dumps, id: \.self) { name in
                    dumpRow(name)
                }
            }
            .padding(12)
        }
        .frame(maxHeight: .infinity)
    }

    private func dumpRow(_ name: String) -> some View {
        let isSelected = selected.contains(name)

        return HStack(spacing: 9) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 14))
                .foregroundStyle(isSelected ? Color.accentColor : Color.secondary.opacity(0.55))

            Text(name)
                .font(.system(size: 12, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer(minLength: 6)

            if hovered == name {
                Button {
                    beginRename(name)
                } label: {
                    Image(systemName: "pencil")
                }
                .buttonStyle(.plain)
                .help(t("html_rename"))

                Button {
                    delete([name])
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.red)
                .help(t("html_delete"))
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 34)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isSelected ? Color.accentColor.opacity(0.14) : Color.primary.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(
                    isSelected ? Color.accentColor.opacity(0.35) : Color.clear,
                    lineWidth: 1
                )
        )
        .contentShape(Rectangle())
        .onTapGesture {
            toggle(name)
        }
        .onHover { hovering in
            hovered = hovering ? name : (hovered == name ? nil : hovered)
        }
        .contextMenu {
            Button(t("html_edit_dump")) {
                edit(name)
            }
            Button(t("html_rename")) {
                beginRename(name)
            }
            Divider()
            Button(t("html_delete"), role: .destructive) {
                delete([name])
            }
        }
    }

    private var bottomBar: some View {
        HStack(spacing: 8) {
            Button(t("html_compute_dump")) {
                compareSelected()
            }
            .disabled(selected.count != 2)

            Button(t("html_edit_dump")) {
                if let name = selected.single {
                    edit(name)
                }
            }
            .disabled(selected.count != 1)

            Button(t("html_delete_checked"), role: .destructive) {
                delete(Array(selected))
            }
            .disabled(selected.isEmpty)

            Spacer()

            Text(
                selected.isEmpty
                    ? t("html_no_selection")
                    : String(format: t("html_selection_count"), selected.count)
            )
            .font(.system(size: 10))
            .foregroundStyle(.secondary)
        }
        .controlSize(.small)
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(.bar)
    }

    // MARK: - Actions

    private func toggle(_ name: String) {
        if selected.contains(name) {
            selected.remove(name)
        } else {
            selected.insert(name)
        }
    }

    private func beginRename(_ name: String) {
        renameTarget = name
        renameText = name
        showRename = true
    }

    private func delete(_ names: [String]) {
        guard !names.isEmpty else { return }
        model.deleteDumps(names)
        for name in names {
            selected.remove(name)
        }
    }

    private func edit(_ name: String) {
        model.prepareDumpEditor(file: model.dumpURL(for: name))
        openWindow(id: "dumpEditor")
    }

    private func compareSelected() {
        let names = model.dumps.filter { selected.contains($0) }
        guard names.count == 2 else { return }
        model.prepareComparator(
            a: model.dumpURL(for: names[0]),
            b: model.dumpURL(for: names[1])
        )
        openWindow(id: "dumpComparator")
    }
}

private extension Set {
    var single: Element? {
        count == 1 ? first : nil
    }
}
