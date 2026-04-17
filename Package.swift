// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TimeTracker",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-testing.git", from: "0.12.0"),
    ],
    targets: [
        .executableTarget(
            name: "TimeTracker",
            path: "TimeTracker",
            exclude: ["Info.plist", "TimeTracker.entitlements"],
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "TimeTrackerTests",
            dependencies: [
                "TimeTracker",
                .product(name: "Testing", package: "swift-testing"),
            ],
            path: "Tests"
        ),
    ]
)
