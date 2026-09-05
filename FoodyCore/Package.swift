// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FoodyCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "FoodyCore", targets: ["FoodyCore"])
    ],
    targets: [
        .target(name: "FoodyCore", path: "Sources/FoodyCore"),
        .testTarget(name: "FoodyCoreTests", dependencies: ["FoodyCore"], path: "Tests/FoodyCoreTests")
    ]
)
