// swift-tools-version:6.0
import PackageDescription

// The swift-protobuf requirement here is a range, not an exact pin: it is the
// *runtime* a consumer links, and that is the consumer's choice.
//
// The pin that makes the committed output reproducible lives in
// Tools/protoc-plugin, which builds the protoc-gen-swift that emits
// Sources/DifferentRequestsProtos. Pinning the generator is what this package
// owes its consumers; pinning the runtime would only constrain them.
let package = Package(
  name: "differentrequests-proto",
  platforms: [
    .iOS(.v18),
    .macOS(.v15)
  ],
  products: [
    .library(
      name: "DifferentRequestsProtos",
      targets: ["DifferentRequestsProtos"]
    )
  ],
  dependencies: [
    .package(url: "https://github.com/apple/swift-protobuf.git", from: "1.30.0")
  ],
  targets: [
    // One target, holding the domain, the options, and the SDK surface.
    //
    // The public/private split this package enforces is about which files a
    // *generator* reads, not about which target a type lands in — a second
    // target would suggest the boundary is a link-time property, which it is
    // not. What would justify splitting: a consumer with a binary-size budget
    // that links a subset, the way backlog-proto isolates its widget contract.
    .target(
      name: "DifferentRequestsProtos",
      dependencies: [
        .product(name: "SwiftProtobuf", package: "swift-protobuf")
      ]
    )
  ]
)
