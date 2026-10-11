// swift-tools-version: 6.4
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Pencild",
    platforms: [
        .iOS(.v17),
    ],
    targets: [
        .executableTarget(
            name: "Pencild",
            path: "Sources/Pencild",
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
            ]
        ),
        .testTarget(
            name: "PencildTests",
            dependencies: ["Pencild"],
            path: "Tests/PencildTests",
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
            ]
        ),
    ]
)
