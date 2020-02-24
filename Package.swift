// swift-tools-version:5.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SPUndoManager",
    products: [
        .library(name: "SPUndoManager", targets: ["SPUndoManager"])
    ],
    dependencies: [],
    targets: [
        .target(name: "SPUndoManager", dependencies: [], path: "./SPUndoManager")
    ]
)
