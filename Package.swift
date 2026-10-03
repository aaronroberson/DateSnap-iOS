// swift-tools-version: 6.4
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "DateSnap",
    platforms: [
        .iOS(.v17),
    ],
    targets: [
        .executableTarget(
            name: "DateSnap",
            path: "Sources/DateSnap",
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
            ]
        ),
        .testTarget(
            name: "DateSnapTests",
            dependencies: ["DateSnap"],
            path: "Tests/DateSnapTests",
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
            ]
        ),
    ]
)
