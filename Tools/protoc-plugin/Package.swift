// swift-tools-version:6.0
import PackageDescription

// Host build tooling, kept in its own manifest so it can pin swift-protobuf
// exactly without imposing that version on anything linking
// DifferentRequestsProtos.
//
// `swift build --product protoc-gen-swift` here resolves the plugin from this
// pinned dependency rather than from PATH. An ambient protoc-gen-swift at a
// different version reformats every generated file, which would make the
// committed output depend on whatever a given machine happened to install — and
// the regenerate-and-diff check then fails for a reason that has nothing to do
// with the contract.
//
// Pinned to the same version backlog-proto pins, so the two contract packages in
// this org emit identically formatted Swift.
//
// Every generator here is a protoc plugin, the same shape protoc-gen-swift is:
// protoc parses the schema and hands over descriptors, and the custom options are
// declared to the library rather than matched out of text. None of them opens a
// .proto file. A generator that read the text would be a second implementation of
// a grammar protoc already implements, and wrong wherever the two disagree — a
// brace opened by a `oneof` closing a message, a `//` inside a string literal
// starting a comment, a declaration split across lines never seen at all.
let package = Package(
  name: "protoc-plugin",
  platforms: [.macOS("15.0")],
  products: [
    .executable(name: "protoc-gen-drendpoints", targets: ["protoc-gen-drendpoints"]),
    .executable(name: "protoc-gen-drtokens", targets: ["protoc-gen-drtokens"]),
    .executable(name: "protoc-gen-drfields", targets: ["protoc-gen-drfields"]),
    .executable(name: "protoc-gen-drvocab", targets: ["protoc-gen-drvocab"]),
    .executable(name: "protoc-gen-drprices", targets: ["protoc-gen-drprices"])
  ],
  dependencies: [
    .package(url: "https://github.com/apple/swift-protobuf.git", exact: "1.33.3")
  ],
  targets: [
    // What every generator here needs and none of them should each hold a copy of: the contract's
    // custom options declared once, and the naming a generated file is built from.
    .target(
      name: "ContractGeneration",
      dependencies: [
        .product(name: "SwiftProtobuf", package: "swift-protobuf"),
        .product(name: "SwiftProtobufPluginLibrary", package: "swift-protobuf")
      ]
    ),
    .executableTarget(
      name: "protoc-gen-drendpoints",
      dependencies: [
        "ContractGeneration",
        .product(name: "SwiftProtobuf", package: "swift-protobuf"),
        .product(name: "SwiftProtobufPluginLibrary", package: "swift-protobuf")
      ]
    ),
    .executableTarget(
      name: "protoc-gen-drtokens",
      dependencies: [
        "ContractGeneration",
        .product(name: "SwiftProtobuf", package: "swift-protobuf"),
        .product(name: "SwiftProtobufPluginLibrary", package: "swift-protobuf")
      ]
    ),
    .executableTarget(
      name: "protoc-gen-drfields",
      dependencies: [
        "ContractGeneration",
        .product(name: "SwiftProtobuf", package: "swift-protobuf"),
        .product(name: "SwiftProtobufPluginLibrary", package: "swift-protobuf")
      ]
    ),
    .executableTarget(
      name: "protoc-gen-drvocab",
      dependencies: [
        "ContractGeneration",
        .product(name: "SwiftProtobuf", package: "swift-protobuf"),
        .product(name: "SwiftProtobufPluginLibrary", package: "swift-protobuf")
      ]
    ),
    .executableTarget(
      name: "protoc-gen-drprices",
      dependencies: [
        "ContractGeneration",
        .product(name: "SwiftProtobuf", package: "swift-protobuf"),
        .product(name: "SwiftProtobufPluginLibrary", package: "swift-protobuf")
      ]
    )
  ]
)
