// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MetrolistiOS",
    platforms: [
        .iOS(.v26)
    ],
    products: [
        .library(name: "MetrolistCore", targets: ["MetrolistCore"]),
        .library(name: "MetrolistNetworking", targets: ["MetrolistNetworking"]),
        .library(name: "MetrolistPersistence", targets: ["MetrolistPersistence"]),
        .library(name: "MetrolistPlayback", targets: ["MetrolistPlayback"]),
        .library(name: "MetrolistUI", targets: ["MetrolistUI"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-protobuf.git", from: "1.28.0"),
        .package(url: "https://github.com/scinfu/SwiftSoup.git", from: "2.7.0"),
        .package(url: "https://github.com/kean/Nuke.git", from: "12.8.0"),
        .package(url: "https://github.com/hmlongco/Factory.git", from: "2.4.0"),
    ],
    targets: [
        .target(
            name: "MetrolistCore",
            dependencies: [
                .product(name: "SwiftProtobuf", package: "swift-protobuf"),
            ],
            path: "Sources/Core"
        ),
        .target(
            name: "MetrolistNetworking",
            dependencies: [
                "MetrolistCore",
                "SwiftSoup",
            ],
            path: "Sources/Networking"
        ),
        .target(
            name: "MetrolistPersistence",
            dependencies: [
                "MetrolistCore",
            ],
            path: "Sources/Persistence"
        ),
        .target(
            name: "MetrolistPlayback",
            dependencies: [
                "MetrolistCore",
                "MetrolistNetworking",
                "MetrolistPersistence",
            ],
            path: "Sources/Playback"
        ),
        .target(
            name: "MetrolistUI",
            dependencies: [
                "MetrolistCore",
                "MetrolistNetworking",
                "MetrolistPersistence",
                "MetrolistPlayback",
                .product(name: "NukeUI", package: "Nuke"),
                .product(name: "Factory", package: "Factory"),
            ],
            path: "Sources/UI"
        ),
        .testTarget(
            name: "MetrolistCoreTests",
            dependencies: ["MetrolistCore"],
            path: "Tests/CoreTests"
        ),
        .testTarget(
            name: "MetrolistNetworkingTests",
            dependencies: ["MetrolistNetworking"],
            path: "Tests/NetworkingTests"
        ),
    ]
)
