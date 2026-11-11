// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "VpnRealityCore",
    platforms: [
        .iOS(.v16),
        .macOS(.v13),
    ],
    products: [
        .library(name: "VpnRealityCore", targets: ["VpnRealityCore"]),
        .executable(name: "vpnreality-config", targets: ["vpnreality-config"]),
    ],
    targets: [
        .target(name: "VpnRealityCore"),
        .executableTarget(
            name: "vpnreality-config",
            dependencies: ["VpnRealityCore"],
            path: "Sources/vpnreality-config"
        ),
        .testTarget(
            name: "VpnRealityCoreTests",
            dependencies: ["VpnRealityCore"]
        ),
    ]
)
