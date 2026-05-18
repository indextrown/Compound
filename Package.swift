// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import CompilerPluginSupport
import PackageDescription

let package = Package(
    name: "Compound",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "Compound",
            targets: ["Compound"]
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
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "Compound",
            dependencies: [
                "CompoundMacros"
            ]
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
            dependencies: ["Compound"],
            path: "Sources/CompoundMacro/CompoundMacroClient"
        ),
        .testTarget(
            name: "CompoundTests",
            dependencies: ["Compound"]
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
