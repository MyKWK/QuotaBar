// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "QuotaBar",
    platforms: [
        .macOS("27.0")
    ],
    products: [
        .library(name: "QuotaBarApp", targets: ["QuotaBarApp"]),
        .executable(name: "QuotaBar", targets: ["QuotaBar"])
    ],
    targets: [
        .target(
            name: "QuotaBarApp",
            path: "Sources/QuotaBarApp",
            resources: [
                .process("Resources")
            ],
            linkerSettings: [
                .linkedLibrary("sqlite3"),
                .linkedFramework("Charts")
            ]
        ),
        .executableTarget(
            name: "QuotaBar",
            dependencies: ["QuotaBarApp"],
            path: "Sources/QuotaBar"
        ),
        .testTarget(
            name: "QuotaBarAppTests",
            dependencies: ["QuotaBarApp"],
            path: "Tests/QuotaBarAppTests"
        )
    ]
)
