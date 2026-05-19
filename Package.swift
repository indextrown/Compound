// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import CompilerPluginSupport
import PackageDescription

let package = Package(
    name: "Compound",
    platforms: [
        .iOS(.v17),
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "Compound",
            targets: ["Compound"]
        ),
        .library(
            name: "CompoundKit",
            targets: ["CompoundKit"]
        ),
        .executable(
            name: "CompoundMacroClient",
            targets: ["CompoundMacroClient"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "600.0.0")
    ],
    targets: [
        .target(
            name: "CompoundCore",
            path: "Sources/CompoundCore"
        ),
        .target(
            name: "Compound",
            dependencies: [
                "CompoundCore",
                "CompoundMacros"
            ],
            path: "Sources/Compound"
        ),
        .target(
            name: "CompoundKit",
            dependencies: [
                "CompoundCore",
                "CompoundMacros"
            ],
            path: "Sources/CompoundKit"
        ),
        .macro(
            name: "CompoundMacros",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftSyntaxBuilder", package: "swift-syntax"),
                .product(name: "SwiftDiagnostics", package: "swift-syntax"),
            ],
            path: "Sources/CompoundMacro/CompoundMacros"
        ),
        .executableTarget(
            name: "CompoundMacroClient",
            dependencies: ["Compound", "CompoundKit"],
            path: "Sources/CompoundMacro/CompoundMacroClient"
        ),
        .testTarget(
            name: "CompoundTests",
            dependencies: ["CompoundCore"]
        ),
        .testTarget(
            name: "CompoundKitTests",
            dependencies: ["CompoundKit"]
        ),
        .testTarget(
            name: "CompoundMacrosTests",
            dependencies: [
                "CompoundMacros",
                .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
