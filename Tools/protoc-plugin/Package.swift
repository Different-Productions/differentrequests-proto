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
// The generators declare no dependency at all — each is a pure Swift parser over the
// .proto text and none invokes protoc. What they emit is what protoc-gen-swift does
// not: the rpc table, the URL spelling of an enum value, and a field's wire name.
let package = Package(
  name: "protoc-plugin",
  platforms: [.macOS("15.0")],
  products: [
    .executable(name: "endpoint-gen", targets: ["endpoint-gen"]),
    .executable(name: "tokens-gen", targets: ["tokens-gen"]),
    .executable(name: "fields-gen", targets: ["fields-gen"])
  ],
  dependencies: [
    .package(url: "https://github.com/apple/swift-protobuf.git", exact: "1.33.3")
  ],
  targets: [
    .executableTarget(name: "endpoint-gen"),
    .executableTarget(name: "tokens-gen"),
    .executableTarget(name: "fields-gen")
  ]
)
