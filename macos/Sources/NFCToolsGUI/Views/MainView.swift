import AppKit
import SwiftUI

struct MainView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.openWindow) private var openWindow

    private let columns = Array(
        repeating: GridItem(.flexible(), spacing: 12),
        count: 4
    )

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            actionGrid
            logPanel
        }
        .frame(minWidth: 780, minHeight: 690)
        .background(Color(nsColor: .windowBackgroundColor))
        .background(MainWindowCloseGuard())
        .onAppear { model.scanDevices() }
        .sheet(item: $model.activeSheet) { sheet in
            Group {
                switch sheet {
                case .inputKeys:
                    InputKeysView()
                case .hardNested:
                    HardNestedView()
                case .dictTest:
                    DictTestView()
                }
            }
            .environmentObject(model)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            Image(nsImage: NSApp.applicationIconImage ?? NSImage())
                .resizable()
                .interpolation(.high)
                .frame(width: 30, height: 30)

            Text(t("app_name"))
                .font(.system(size: 16, weight: .semibold))

            Spacer(minLength: 12)

            deviceMenu
            IconBarButton(
                systemImage: "arrow.clockwise",
                help: t("html_refresh")
            ) {
                model.scanDevices()
            }
            if model.selectedDevice != nil {
                IconBarButton(
                    systemImage: "xmark.circle",
                    help: t("html_disconnect")
                ) {
                    model.disconnect()
                }
            }

            Divider()
                .frame(height: 20)

            toolsMenu
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
    }

    private var deviceMenu: some View {
        Menu {
            Button {
                model.scanDevices()
            } label: {
                Label(t("html_refresh"), systemImage: "arrow.clockwise")
            }

            Divider()

            if model.devices.isEmpty {
                Text(t("html_no_device_found"))
            } else {
                ForEach(model.devices, id: \.self) { device in
                    Button {
                        model.selectDevice(device)
                    } label: {
                        if model.selectedDevice == device {
                            Label(model.displayName(for: device), systemImage: "checkmark")
                        } else {
                            Text(model.displayName(for: device))
                        }
                    }
                }
            }

            if model.selectedDevice != nil {
                Divider()
                Button(role: .destructive) {
                    model.disconnect()
                } label: {
                    Label(t("html_disconnect"), systemImage: "xmark.circle")
                }
            }
        } label: {
            HStack(spacing: 7) {
                Circle()
                    .fill(deviceColor)
                    .frame(width: 8, height: 8)
                Text(deviceLabel)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                    .frame(maxWidth: 180)
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .frame(height: 28)
            .background(
                Capsule()
                    .fill(deviceColor.opacity(0.12))
            )
            .overlay(
                Capsule()
                    .strokeBorder(deviceColor.opacity(0.35), lineWidth: 1)
            )
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .disabled(model.connectionState == .connecting)
        .help(model.selectedDevice.map { model.displayName(for: $0) } ?? t("html_choose_device"))
    }

    private var toolsMenu: some View {
        Menu {
            Button {
                model.openHistoricalKeys()
            } label: {
                Label(t("html_edit_history_key"), systemImage: "key")
            }

            Divider()

            Button {
                model.refreshDumps()
                model.prepareDumpEditor(file: nil)
                openWindow(id: "dumpEditor")
            } label: {
                Label(t("html_dump_editor"), systemImage: "square.and.pencil")
            }

            Button {
                model.prepareComparator(a: nil, b: nil)
                openWindow(id: "dumpComparator")
            } label: {
                Label(t("html_dump_comparator"), systemImage: "rectangle.split.2x1")
            }

            Button {
                model.refreshDumps()
                openWindow(id: "dumpHistory")
            } label: {
                Label(t("html_dump_history"), systemImage: "clock.arrow.circlepath")
            }

            Divider()

            Button {
                openWindow(id: "settings")
            } label: {
                Label(t("html_settings"), systemImage: "gearshape")
            }

            Button {
                openWindow(id: "about")
            } label: {
                Label(t("html_about"), systemImage: "info.circle")
            }
        } label: {
            Image(systemName: "wrench.and.screwdriver")
                .font(.system(size: 15, weight: .medium))
                .frame(width: 28, height: 26)
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .help(t("html_tools"))
    }

    // MARK: - Actions

    private var actionGrid: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ActionButton(
                title: t("html_read_card"),
                systemImage: "creditcard",
                color: .blue,
                isBusy: model.isRunningTask
            ) {
                model.readCard()
            }

            ActionButton(
                title: t("html_write_card"),
                systemImage: "square.and.arrow.down",
                color: .orange,
                isBusy: model.isRunningTask
            ) {
                model.writeCard()
            }

            ActionButton(
                title: t("html_format_card"),
                systemImage: "eraser",
                color: .pink,
                isBusy: model.isRunningTask
            ) {
                model.formatCard()
            }

            ActionButton(
                title: t("html_read_card_with_known_key"),
                systemImage: "key",
                color: .purple,
                isBusy: model.isRunningTask
            ) {
                model.openInputKeys()
            }

            ActionButton(
                title: t("html_detect_card"),
                systemImage: "magnifyingglass",
                color: .teal,
                isBusy: model.isRunningTask
            ) {
                model.detectCard()
            }

            ActionButton(
                title: t("html_lock_ufuid"),
                systemImage: "lock.fill",
                color: .red,
                isBusy: model.isRunningTask
            ) {
                model.lockUFUID()
            }

            ActionButton(
                title: t("html_hard_nested"),
                systemImage: "gearshape.2",
                color: .indigo,
                isBusy: model.isRunningTask
            ) {
                model.openHardNested()
            }

            ActionButton(
                title: t("html_test_dictionary"),
                systemImage: "book.closed",
                color: .green,
                isBusy: model.isRunningTask
            ) {
                model.openDictTest()
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 18)
        .padding(.bottom, 16)
    }

    // MARK: - Log

    private var logPanel: some View {
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                Label(t("html_log"), systemImage: "terminal")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .labelStyle(.titleAndIcon)

                Spacer()

                IconBarButton(
                    systemImage: model.lockScroll ? "lock.fill" : "arrow.down.to.line",
                    help: model.lockScroll ? t("html_lock_scroll") : t("html_unlock_scroll"),
                    active: model.lockScroll
                ) {
                    model.lockScroll.toggle()
                }

                IconBarButton(
                    systemImage: "stop.fill",
                    help: t("html_stop_task")
                ) {
                    model.stopTask()
                }

                IconBarButton(
                    systemImage: "square.and.arrow.down",
                    help: t("html_save_log")
                ) {
                    model.saveLog()
                }

                IconBarButton(
                    systemImage: "trash",
                    help: t("html_clear_log")
                ) {
                    model.clearLog()
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)

            Divider()
                .overlay(Color.white.opacity(0.08))

            ScrollViewReader { proxy in
                ScrollView {
                    Text(model.logText.isEmpty ? " " : model.logText)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(AppTheme.logText)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .id("log-end")
                }
                .onReceive(model.$logText) { _ in
                    guard !model.lockScroll else { return }
                    withAnimation(.easeOut(duration: 0.12)) {
                        proxy.scrollTo("log-end", anchor: .bottom)
                    }
                }
            }
            .frame(minHeight: 240)

            Divider()
                .overlay(Color.white.opacity(0.08))

            statusBar
        }
        .background(AppTheme.logBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
        )
        .padding(.horizontal, 18)
        .padding(.bottom, 16)
    }

    private var statusBar: some View {
        HStack(spacing: 10) {
            StatusDot(indicator: model.statusIndicator)
            Text(model.statusText)
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.88))
                .lineLimit(1)

            Spacer(minLength: 12)

            Label(
                model.timerText.isEmpty ? "--:--:--" : model.timerText,
                systemImage: "timer"
            )
            .labelStyle(.titleAndIcon)

            Label(t("html_offline_short"), systemImage: "wifi.slash")
                .help(t("html_offline_notice"))

            Text("\(t("html_current_version")) \(model.versionText)")
                .lineLimit(1)
        }
        .font(.system(size: 10))
        .foregroundStyle(.white.opacity(0.65))
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.04))
    }

    // MARK: - Helpers

    private var deviceLabel: String {
        if let selected = model.selectedDevice {
            return model.displayName(for: selected)
        }
        return t("html_choose_device")
    }

    private var deviceColor: Color {
        switch model.connectionState {
        case .connecting:
            return .yellow
        case .connected:
            return .green
        case .failed:
            return .red
        case .idle:
            return .secondary
        }
    }
}

// MARK: - Main window close guard

/// Intercepts the red close button so a running task can keep the window (and
/// the process it controls) alive unless the user explicitly confirms.
private struct MainWindowCloseGuard: NSViewRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        let coordinator = context.coordinator
        DispatchQueue.main.async {
            coordinator.attach(to: view.window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        let coordinator = context.coordinator
        DispatchQueue.main.async {
            coordinator.attach(to: nsView.window)
        }
    }

    final class Coordinator: NSObject {
        private weak var window: NSWindow?

        func attach(to window: NSWindow?) {
            guard let window, window !== self.window else { return }
            self.window = window
            guard let button = window.standardWindowButton(.closeButton) else { return }
            button.target = self
            button.action = #selector(closePressed)
        }

        @objc private func closePressed() {
            Task { @MainActor in
                guard AppModel.shared.confirmExitIfNeeded() else { return }
                if let delegate = NSApp.delegate as? AppDelegate {
                    delegate.approvedTermination = true
                }
                NSApp.terminate(nil)
            }
        }
    }
}
