// swift-tools-version: 6.0
import PackageDescription
let package = Package(
    name: "BainzurettaCore", platforms: [.iOS(.v18), .macOS(.v14)],
    products: [.library(name: "BainzurettaCore", targets: ["BainzurettaCore"])],
    targets: [.target(name: "BainzurettaCore"),
              .testTarget(name: "BainzurettaCoreTests", dependencies: ["BainzurettaCore"], resources: [.copy("Fixtures")])],
    swiftLanguageModes: [.v5]
)
