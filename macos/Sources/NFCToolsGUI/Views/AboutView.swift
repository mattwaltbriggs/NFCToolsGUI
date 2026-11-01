import AppKit
import SwiftUI

struct AboutView: View {
    private let upstream = URL(string: "https://github.com/GSWXXN/NFCToolsGUI")!
    private let fork = URL(string: "https://github.com/mattwaltbriggs/NFCToolsGUI")!
    private let license = URL(string: "https://github.com/GSWXXN/NFCToolsGUI/blob/main/LICENSE")!

    private let projects: [(name: String, url: String, license: String)] = [
        ("libnfc", "https://github.com/nfc-tools/libnfc", "LGPL-3.0"),
        ("mfoc", "https://github.com/nfc-tools/mfoc", "GPL-2.0"),
        ("crypto1_bs", "https://github.com/aczid/crypto1_bs", "GPL-2.0"),
        ("cropto1_bs", "https://github.com/vk496/cropto1_bs", "GPL-2.0"),
        ("MifareOneTool", "https://github.com/xcicode/MifareOneTool", "GPL-3.0"),
        ("nfc-mflock", "https://github.com/duament/nfc-mflock", "BSD-2-Clause")
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Image(nsImage: NSApp.applicationIconImage ?? NSImage())
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 88, height: 88)

                VStack(spacing: 4) {
                    Text(t("app_name"))
                        .font(.system(size: 24, weight: .bold))
                    Text("\(t("html_version_code"))\(versionText)")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 8) {
                    badge(t("html_native_build"), systemImage: "swift", color: .orange)
                    badge(t("html_offline_short"), systemImage: "wifi.slash", color: .green)
                }

                Text(t("html_about_offline"))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 380)

                Divider()

                VStack(spacing: 8) {
                    infoRow(t("html_builder"), builderText)
                    infoRow(t("html_open_source_repository"), link: upstream.absoluteString, url: upstream)
                    infoRow(t("html_fork"), link: fork.absoluteString, url: fork)
                    infoRow(t("html_license:"), link: "AGPL-3.0", url: license)
                }

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text(t("html_this_program_use_following_open_source_project"))
                        .font(.system(size: 12, weight: .semibold))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    ForEach(projects, id: \.name) { project in
                        HStack(spacing: 8) {
                            Text(project.name)
                                .font(.system(size: 11, weight: .medium))
                                .frame(width: 110, alignment: .leading)
                            if let url = URL(string: project.url) {
                                Link(t("html_source_code"), destination: url)
                                    .font(.system(size: 11))
                            }
                            Text("·")
                                .foregroundStyle(.tertiary)
                            Text("\(t("html_license")) \(project.license)")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                            Spacer(minLength: 0)
                        }
                    }
                }
                .padding(.horizontal, 8)
            }
            .padding(24)
        }
        .frame(width: 580, height: 650)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var versionText: String {
        let short = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "2.0.0"
        return short.hasPrefix("v") ? short : "v\(short)"
    }

    private var builderText: String {
        (Bundle.main.infoDictionary?["NFCToolsGUIBuilder"] as? String) ?? "Native SwiftUI (arm64)"
    }

    private func badge(_ text: String, systemImage: String, color: Color) -> some View {
        Label(text, systemImage: systemImage)
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Capsule().fill(color.opacity(0.12)))
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 150, alignment: .trailing)
            Text(value)
                .font(.system(size: 11))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func infoRow(_ label: String, link: String, url: URL) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 150, alignment: .trailing)
            Link(link, destination: url)
                .font(.system(size: 11))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
