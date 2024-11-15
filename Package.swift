// swift-tools-version:5.1
import PackageDescription

let package = Package(
    name: "FigmaGenerator",
    products: [
        .executable(name: "figmaGenerator", targets: ["FigmaGenerator"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", .upToNextMajor(from: "1.0.0")),
    ],
    targets: [
        .target(name: "FigmaGenerator",
                dependencies: [.product(name: "ArgumentParser", package: "swift-argument-parser"),]),
    ]
)
