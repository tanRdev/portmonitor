// swift-tools-version:6.2
import PackageDescription

let package = Package(
    name: "PortMonitor",
    platforms: [
        .macOS(.v26)
    ],
    products: [
        .executable(
            name: "PortMonitor",
            targets: ["PortMonitor"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-testing.git", from: "6.2.0")
    ],
    targets: [
        .executableTarget(
            name: "PortMonitor",
            path: "PortMonitor",
            exclude: ["Info.plist", "Assets"],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "PortMonitorTests",
            dependencies: [
                "PortMonitor",
                .product(name: "Testing", package: "swift-testing")
            ],
            path: "Tests/PortMonitorTests"
        )
    ]
)
