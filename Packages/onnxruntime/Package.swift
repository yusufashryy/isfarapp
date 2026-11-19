// swift-tools-version: 5.9

// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License (see LICENSE).
//
// Niyat's copy of microsoft/onnxruntime-swift-package-manager at 1.24.2
// (commit b7fb7f7), kept in the repo because the upstream GitHub repository
// was removed on 17 Nov 2026. Only the Objective-C bindings the app uses are
// kept; the runtime itself is still Microsoft's prebuilt framework, downloaded
// from download.onnxruntime.ai and checked against its SHA-256.

import PackageDescription

let package = Package(
    name: "onnxruntime",
    platforms: [.iOS(.v15), .macOS(.v14)],
    products: [
        .library(name: "onnxruntime", type: .static, targets: ["OnnxRuntimeBindings"]),
    ],
    targets: [
        .target(name: "OnnxRuntimeBindings",
                dependencies: ["onnxruntime"],
                path: "objectivec",
                exclude: ["ReadMe.md"],
                cxxSettings: [.define("SPM_BUILD")]),
        .binaryTarget(name: "onnxruntime",
                      url: "https://download.onnxruntime.ai/pod-archive-onnxruntime-c-1.24.2.zip",
                      checksum: "f7100a992d2a8135168c8afd831e6a58b465349101982aa58b3e11d36e600b54"),
    ],
    cxxLanguageStandard: .cxx17
)
