// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DocConverter",
    defaultLocalization: "vi",
    platforms: [.macOS(.v15)],
    targets: [
        .target(name: "DocConverterKit"),
        .executableTarget(name: "DocConverter", dependencies: ["DocConverterKit"]),
        .testTarget(name: "DocConverterKitTests", dependencies: ["DocConverterKit"]),
    ]
)
