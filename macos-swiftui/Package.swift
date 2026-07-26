// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "SamekoMac",
    platforms: [.macOS(.v26)],
    products: [
        .executable(name: "SamekoMac", targets: ["SamekoMac"]),
    ],
    targets: [
        .executableTarget(
            name: "SamekoMac",
            resources: [.copy("Resources")]
        ),
    ]
)
