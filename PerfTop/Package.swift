// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PerfTop",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(
            name: "PerfTop",
            targets: ["PerfTop"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "6.0.0"),
        .package(url: "https://github.com/onevcat/Kingfisher.git", from: "7.0.0"),
        .package(url: "https://github.com/danielgindi/Charts.git", from: "5.0.0")
    ],
    targets: [
        .target(
            name: "PerfTop",
            dependencies: [
                .product(name: "GRDB", package: "GRDB.swift"),
                .product(name: "Kingfisher", package: "Kingfisher"),
                .product(name: "Charts", package: "Charts")
            ]
        ),
        .testTarget(
            name: "PerfTopTests",
            dependencies: ["PerfTop"]
        )
    ]
)
