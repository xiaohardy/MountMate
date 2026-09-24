// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MountMate",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "MountMateCore", targets: ["MountMateCore"]),
        .executable(name: "MountMate", targets: ["MountMate"])
    ],
    targets: [
        .target(name: "MountMateCore", resources: [.process("Resources")]),
        .executableTarget(name: "MountMate", dependencies: ["MountMateCore"]),
        .testTarget(name: "MountMateCoreTests", dependencies: ["MountMateCore"]),
        .testTarget(name: "MountMateStorageTests", dependencies: ["MountMate", "MountMateCore"])
    ]
)
