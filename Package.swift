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
            // Resources (the asset catalog) are excluded: compiling .xcassets needs actool,
            // which only ships with full Xcode. build-app.sh generates AppIcon.icns from the
            // PNG directly, and the xcodegen project handles the catalog itself.
            exclude: ["Info.plist", "TimeTracker.entitlements", "Resources"]
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
