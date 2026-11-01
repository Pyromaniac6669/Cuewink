// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Cuewink",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "Cuewink", targets: ["NotifyTool"])],
    targets: [.executableTarget(name: "NotifyTool")]
)
