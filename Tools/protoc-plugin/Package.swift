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
// endpoint-gen declares no dependency at all — it is a pure Swift parser over the
// .proto text and never invokes protoc. swift-protobuf generates no service code, so
// there is no descriptor carrying the rpc list at the point the table is needed.
let package = Package(
  name: "protoc-plugin",
  platforms: [.macOS("15.0")],
  products: [
    .executable(name: "endpoint-gen", targets: ["endpoint-gen"])
  ],
  dependencies: [
    .package(url: "https://github.com/apple/swift-protobuf.git", exact: "1.33.3")
  ],
  targets: [
    .executableTarget(name: "endpoint-gen")
  ]
)
