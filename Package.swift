// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "replace4sc",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "FourScoreKit", targets: ["FourScoreKit"]),
        .executable(name: "replace4sc", targets: ["replace4sc"]),
        .executable(name: "FourScorePDFReplacer", targets: ["FourScorePDFReplacer"]),
    ],
    targets: [
        .target(name: "FourScoreKit"),
        .executableTarget(name: "replace4sc", dependencies: ["FourScoreKit"]),
        .executableTarget(name: "FourScorePDFReplacer", dependencies: ["FourScoreKit"]),
        .testTarget(name: "FourScoreKitTests", dependencies: ["FourScoreKit"]),
    ]
)
