// swift-tools-version:5.3

import PackageDescription

let package = Package(
    name: "combine-schedulers",
    platforms: [
        .iOS(.v14),
        .macOS(.v11)
    ],
    products: [
        .library(name: "CombineSchedulers", targets: ["CombineSchedulers"])
    ],
    targets: [
        .target(name: "CombineSchedulers"),
        .testTarget(name: "CombineSchedulersTests", dependencies: ["CombineSchedulers"]),
    ]
)
