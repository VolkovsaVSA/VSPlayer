// swift-tools-version:5.9
import Foundation
import PackageDescription

let package = Package(
    name: "VSPlayer",
    defaultLocalization: "en",
    platforms: [.macOS(.v10_15), .macCatalyst(.v14), .iOS(.v13), .tvOS(.v13),
                .visionOS(.v1)],
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library(
            name: "VSPlayer",
            // todo clang: warning: using sysroot for 'iPhoneSimulator' but targeting 'MacOSX' [-Wincompatible-sysroot]
//            type: .dynamic,
            targets: ["VSPlayer"]
        ),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        .target(
            name: "VSPlayer",
            dependencies: [
                .product(name: "FFmpegKit", package: "FFmpegKit"),
//                .product(name: "Libass", package: "FFmpegKit"),
//                .product(name: "Libmpv", package: "FFmpegKit"),
                "DisplayCriteria",
            ],
            resources: [.process("Metal/Shaders.metal")],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency"),
            ]
        ),
        .target(
            name: "DisplayCriteria"
        ),
        .testTarget(
            name: "VSPlayerTests",
            dependencies: ["VSPlayer"],
            resources: [.process("Resources")]
        ),
    ]
)

package.dependencies += [
    // Forked FFmpegKit (kingslay/FFmpegKit @ 6.1.3) with a single fix: the invalid
    // CFBundleIdentifier of `libshaderc_combined` is sanitized (`_` -> `-`) so Xcode /
    // App Store validation passes without a runtime build-phase workaround.
    //
    .package(url: "https://github.com/VolkovsaVSA/FFmpegKit.git", exact: "6.1.3"),
]
