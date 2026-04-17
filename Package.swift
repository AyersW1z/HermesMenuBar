// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "HermesMenuBar",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "HermesMenuBar",
            path: "HermesMenuBar",
            exclude: ["Info.plist"],
            swiftSettings: [
                .unsafeFlags([
                    "-parse-as-library"
                ])
            ]
        )
    ]
)
