// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "NFCToolsGUI",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "NFCToolsGUI", targets: ["NFCToolsGUI"])
    ],
    targets: [
        .executableTarget(
            name: "NFCToolsGUI",
            path: "Sources/NFCToolsGUI"
        )
    ]
)
