// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "mac-keyboard-mapping",
    platforms: [
.macOS(.v13),
    ],
    products: [
        .executable(
            name: "rightcmd-agent",
            targets: ["RightCmdAgent"]
        ),
    ],
    targets: [
        .executableTarget(
            name: "RightCmdAgent",
            path: "Sources/mac-keyboard-mapping"
        ),
        .testTarget(
            name: "RightCmdAgentTests",
            dependencies: ["RightCmdAgent"]
        ),
    ]
)
