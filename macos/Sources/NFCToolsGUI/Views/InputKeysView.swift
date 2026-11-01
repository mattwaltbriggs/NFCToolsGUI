import SwiftUI

struct InputKeysView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    @State private var keys = "ffffffffffff,"

    var body: some View {
        VStack(spacing: 18) {
            SheetTitle(
                title: t("html_please_input_known_keys"),
                subtitle: t("html_please_input_known_keys_split_by_comma")
            )

            TextField("ffffffffffff, a0a1a2a3a4a5", text: $keys)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 13, design: .monospaced))
                .frame(width: 330)

            SheetButtons(
                confirmTitle: t("dialog_button_ok"),
                cancel: {
                    model.activeSheet = nil
                    dismiss()
                },
                confirm: execute
            )
        }
        .padding(24)
        .frame(width: 410)
    }

    private func execute() {
        guard FieldValidation.containsKey(keys) else {
            model.showError(t("dialog_title_error"), t("dialog_msg_invalid_keys"))
            return
        }
        model.activeSheet = nil
        dismiss()
        model.executeInputKeys(keys)
    }
}
