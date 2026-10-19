// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "BedrockConnect",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "BedrockConnectCore",
            targets: ["BedrockConnectCore"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "BedrockConnectCore",
            path: "BedrockConnect",
            exclude: ["App/Info.plist", "Resources", "App/BedrockConnectApp.swift"]
        ),
        .testTarget(
            name: "BedrockConnectTests",
            dependencies: ["BedrockConnectCore"],
            path: "Tests/BedrockConnectTests"
        ),
    ]
)
