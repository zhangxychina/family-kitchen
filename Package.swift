// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "FamilyTable", platforms: [.macOS(.v13), .iOS(.v17)], products: [.library(name: "FamilyCore", targets: ["FamilyCore"])], targets: [.target(name: "FamilyCore"), .testTarget(name: "FamilyCoreTests", dependencies: ["FamilyCore"])])
