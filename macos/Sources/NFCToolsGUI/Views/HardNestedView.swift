import SwiftUI

struct HardNestedView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    @State private var config = HardNestedConfig()

    var body: some View {
        VStack(spacing: 18) {
            SheetTitle(
                title: t("html_hard_nested"),
                subtitle: t("html_known_info")
            )

            Toggle(t("html_auto_run"), isOn: $config.autoRun)
                .toggleStyle(.switch)
                .frame(maxWidth: .infinity, alignment: .leading)

            Divider()

            VStack(spacing: 10) {
                FieldRow(
                    label: t("html_known_key"),
                    text: $config.knownKey,
                    width: 180,
                    prompt: "ffffffffffff"
                )
                FieldRow(
                    label: t("html_sector"),
                    text: $config.knownSector,
                    width: 80,
                    prompt: "0"
                )
                HStack(spacing: 12) {
                    Text(t("html_key_type"))
                        .frame(width: 120, alignment: .trailing)
                        .foregroundStyle(.secondary)
                    KeyTypePicker(selection: $config.knownKeyType)
                    Spacer(minLength: 0)
                }
            }
            .disabled(config.autoRun)
            .opacity(config.autoRun ? 0.45 : 1)

            Divider()

            SectionLabel(text: t("html_target_sector_info"))

            VStack(spacing: 10) {
                FieldRow(
                    label: t("html_sector"),
                    text: $config.targetSector,
                    width: 80,
                    prompt: "0"
                )
                HStack(spacing: 12) {
                    Text(t("html_key_type"))
                        .frame(width: 120, alignment: .trailing)
                        .foregroundStyle(.secondary)
                    KeyTypePicker(selection: $config.targetKeyType)
                    Spacer(minLength: 0)
                }
            }
            .disabled(config.autoRun)
            .opacity(config.autoRun ? 0.45 : 1)

            Toggle(t("html_collect_only"), isOn: $config.collectOnly)
                .toggleStyle(.switch)
                .disabled(config.autoRun)
                .opacity(config.autoRun ? 0.45 : 1)
                .frame(maxWidth: .infinity, alignment: .leading)

            SheetButtons(
                cancel: {
                    model.activeSheet = nil
                    dismiss()
                },
                confirm: execute
            )
        }
        .padding(24)
        .frame(width: 460)
        .onAppear { config = model.hardNestedConfig }
    }

    private func execute() {
        if !config.autoRun {
            guard FieldValidation.isKey(config.knownKey) else {
                model.showError(t("dialog_title_error"), t("dialog_msg_invalid_key"))
                return
            }
            guard FieldValidation.isSector(config.knownSector) else {
                model.showError(t("dialog_title_error"), t("dialog_msg_invalid_sector"))
                return
            }
            guard FieldValidation.isSector(config.targetSector) else {
                model.showError(t("dialog_title_error"), t("dialog_msg_invalid_sector"))
                return
            }
        }

        let submitted = config
        model.activeSheet = nil
        dismiss()
        model.executeHardNested(submitted)
    }
}
