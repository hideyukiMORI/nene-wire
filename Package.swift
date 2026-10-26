// swift-tools-version: 6.2
// tools-version は manifest の API の版であり、ツールチェーンの版（.swift-version）ではない。
// 6.2 は treatAllWarnings(as:) を使える最小の版（ADR 0001）。
// target は承認された依存グラフ（docs/architecture/module-graph.txt・ADR 0004）から、最初の責務が生じた PR で足す。
// 各 target の swiftSettings は [.treatAllWarnings(as: .error), .enableUpcomingFeature("ExistentialAny")]（CNF-009）。

import PackageDescription

let package = Package(
    name: "NeNeWire",
    targets: [
        .target(
            name: "NeNeWireCore",
            swiftSettings: [.treatAllWarnings(as: .error), .enableUpcomingFeature("ExistentialAny")]
        ),
        .target(
            name: "NeNeWireRender",
            dependencies: ["NeNeWireCore"],
            swiftSettings: [.treatAllWarnings(as: .error), .enableUpcomingFeature("ExistentialAny")]
        ),
        .target(
            name: "NeNeWireTerminal",
            dependencies: ["NeNeWireRender"],
            swiftSettings: [.treatAllWarnings(as: .error), .enableUpcomingFeature("ExistentialAny")]
        ),
        .target(
            name: "NeNeWireHost",
            dependencies: ["NeNeWireCore"],
            swiftSettings: [.treatAllWarnings(as: .error), .enableUpcomingFeature("ExistentialAny")]
        ),
        .executableTarget(
            name: "nene-wire",
            dependencies: ["NeNeWireCore", "NeNeWireRender", "NeNeWireTerminal", "NeNeWireHost"],
            swiftSettings: [.treatAllWarnings(as: .error), .enableUpcomingFeature("ExistentialAny")]
        ),
        .testTarget(
            name: "NeNeWireCoreTests",
            dependencies: ["NeNeWireCore"],
            swiftSettings: [.treatAllWarnings(as: .error), .enableUpcomingFeature("ExistentialAny")]
        ),
        .testTarget(
            name: "NeNeWireRenderTests",
            dependencies: ["NeNeWireCore", "NeNeWireRender"],
            swiftSettings: [.treatAllWarnings(as: .error), .enableUpcomingFeature("ExistentialAny")]
        ),
        .testTarget(
            name: "NeNeWireTerminalTests",
            dependencies: ["NeNeWireRender", "NeNeWireTerminal"],
            swiftSettings: [.treatAllWarnings(as: .error), .enableUpcomingFeature("ExistentialAny")]
        ),
        .testTarget(
            name: "NeNeWireHostTests",
            dependencies: ["NeNeWireCore", "NeNeWireHost"],
            swiftSettings: [.treatAllWarnings(as: .error), .enableUpcomingFeature("ExistentialAny")]
        ),
    ],
    swiftLanguageModes: [.v6]
)
