import AppKit
import SwiftUI

struct SettingsView: View {
    @AppStorage("appearance") private var appearance = "system"

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text(t("html_settings"))
                .font(.system(size: 18, weight: .semibold))

            VStack(alignment: .leading, spacing: 10) {
                SectionLabel(text: t("html_appearance"))
                Picker("", selection: $appearance) {
                    Text(t("html_appearance_system")).tag("system")
                    Text(t("html_appearance_light")).tag("light")
                    Text(t("html_appearance_dark")).tag("dark")
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 330)
            }

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                SectionLabel(text: t("html_data_directory"))
                HStack(spacing: 8) {
                    Text(AppPaths.appSupport.path)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                    Spacer()
                    Button(t("html_reveal_in_finder")) {
                        NSWorkspace.shared.open(AppPaths.appSupport)
                    }
                    .controlSize(.small)
                }
            }

            Divider()

            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "wifi.slash")
                    .foregroundStyle(.green)
                    .font(.system(size: 15))
                VStack(alignment: .leading, spacing: 3) {
                    Text(t("html_offline"))
                        .font(.system(size: 12, weight: .semibold))
                    Text(t("html_offline_notice"))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 0)

            Text("\(t("html_version_code"))\(versionText) · \(builderText)")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
        .padding(24)
        .frame(width: 500, height: 380, alignment: .topLeading)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var versionText: String {
        let short = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "2.0.0"
        return short.hasPrefix("v") ? short : "v\(short)"
    }

    private var builderText: String {
        (Bundle.main.infoDictionary?["NFCToolsGUIBuilder"] as? String) ?? "Native SwiftUI (arm64)"
    }
}
