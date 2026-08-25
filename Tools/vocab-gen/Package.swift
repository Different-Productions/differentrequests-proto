// swift-tools-version:6.0
import PackageDescription

// Host build tooling, kept in its own manifest so it can pin swift-protobuf exactly
// without imposing that version on anything that links DifferentRequestsProtos.
//
// The pin matches Tools/protoc-plugin: vocab-gen reads the same descriptors
// protoc-gen-swift reads and reuses SwiftProtobufPluginLibrary's namer, so the case
// names it emits and the case names in the .pb.swift files are produced by one
// implementation at one version.
let package = Package(
  name: "vocab-gen",
  platforms: [.macOS("15.0")],
  dependencies: [
    .package(url: "https://github.com/apple/swift-protobuf.git", exact: "1.33.3")
  ],
  targets: [
    .executableTarget(
      name: "vocab-gen",
      dependencies: [
        .product(name: "SwiftProtobuf", package: "swift-protobuf"),
        .product(name: "SwiftProtobufPluginLibrary", package: "swift-protobuf")
      ],
      path: "Sources/vocab-gen"
    )
  ]
)
