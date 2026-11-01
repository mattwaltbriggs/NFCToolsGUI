import SwiftUI

struct DictTestView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    @State private var config = DictTestConfig()

    var body: some View {
        VStack(spacing: 16) {
            SheetTitle(
                title: t("html_test_dictionary"),
                subtitle: t("html_input_test_info")
            )

            HStack(spacing: 12) {
                Text(t("html_dictionary_file"))
                    .frame(width: 120, alignment: .trailing)
                    .foregroundStyle(.secondary)
                Text(model.dictDisplayName)
                    .font(.system(size: 12))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button(t("html_choose_file")) {
                    model.chooseDictionaryFile()
                }
            }

            FieldRow(
                label: t("html_sector"),
                text: $config.sector,
                width: 80,
                prompt: "0"
            )

            HStack(spacing: 12) {
                Text(t("html_key_type"))
                    .frame(width: 120, alignment: .trailing)
                    .foregroundStyle(.secondary)
                KeyTypePicker(selection: $config.keyType)
                Spacer(minLength: 0)
            }

            FieldRow(
                label: t("html_start_position"),
                text: $config.startPosition,
                width: 80,
                prompt: "0"
            )

            Spacer(minLength: 4)

            SheetButtons(
                confirmTitle: t("html_execute"),
                cancel: {
                    model.activeSheet = nil
                    dismiss()
                },
                confirm: execute
            )
        }
        .padding(24)
        .frame(width: 460)
        .onAppear { config = model.dictTestConfig }
    }

    private func execute() {
        guard FieldValidation.isSector(config.sector) else {
            model.showError(t("dialog_title_error"), t("dialog_msg_invalid_sector"))
            return
        }
        guard FieldValidation.isStartPosition(config.startPosition) else {
            model.showError(t("dialog_title_error"), t("dialog_msg_invalid_start_position"))
            return
        }

        let submitted = config
        model.activeSheet = nil
        dismiss()
        model.executeDictTest(submitted)
    }
}
