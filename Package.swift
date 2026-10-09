// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DevWatch",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "DevWatch", targets: ["DevWatch"]),
        .library(name: "DevWatchCore", targets: ["DevWatchCore"])
    ],
    targets: [
        .target(
            name: "DevWatchCore",
            path: "Sources/DevWatchCore"
        ),
        .executableTarget(
            name: "DevWatch",
            dependencies: ["DevWatchCore"],
            path: "Sources/DevWatch"
        ),
        .testTarget(
            name: "DevWatchTests",
            dependencies: ["DevWatchCore"],
            path: "Tests/DevWatchTests"
        )
    ]
)
