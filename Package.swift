// swift-tools-version: 6.2
import PackageDescription
let package = Package(
    name: "ScreenshotRenamer",
    platforms: [.macOS("27.0")],
    products: [.executable(name: "ScreenshotRenamer", targets: ["ScreenshotRenamer"])],
    targets: [
        .target(name: "RenamerCore"),
        .executableTarget(name: "ScreenshotRenamer", dependencies: ["RenamerCore"]),
        .testTarget(name: "RenamerCoreTests", dependencies: ["RenamerCore"])
    ]
)
