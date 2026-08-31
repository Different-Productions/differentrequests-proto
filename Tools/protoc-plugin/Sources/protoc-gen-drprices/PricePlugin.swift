import ContractGeneration
import Foundation
import SwiftProtobuf
import SwiftProtobufPluginLibrary

/// Emits, for every enum value that declares `(monthly_cents)`, what it costs.
///
/// A price is not a spelling, which is why this is its own generator rather than a third property
/// on tokens-gen. What a value is *called* on the wire and what it *costs* change for different
/// reasons, at different times, and reviewing one should not mean reading the other.
///
/// The server that charges, the console that quotes and the page that advertises are three copies
/// of one number the moment it is typed anywhere but the schema — and the copy that drifts is
/// discovered by a customer, on their card. Emitting it here is what makes those three one fact.
///
/// The total is deliberately not emitted. Summing a taper is behaviour, and it belongs on a type in
/// the deployable that owns the bill; what a schema can state is what each step costs.
///
/// Output is a pure function of the descriptors protoc hands over: enums in declaration order,
/// values in declaration order, no timestamps and no host paths.
@main
struct PricePlugin: CodeGenerator {

  var version: String? { "1.0.0" }

  var projectURL: String? {
    "https://github.com/Different-Productions/differentrequests-proto"
  }

  var supportedFeatures: [Google_Protobuf_Compiler_CodeGeneratorResponse.Feature] {
    [.proto3Optional]
  }

  /// protoc surfaces `(monthly_cents)` as a decoded value only because it is declared here.
  var customOptionExtensions: [any AnyMessageExtension] {
    contractOptionExtensions
  }

  func generate(
    files: [FileDescriptor],
    parameter: any CodeGeneratorParameter,
    protoCompilerContext: any ProtoCompilerContext,
    generatorOutputs: any GeneratorOutputs
  ) throws {
    let namer = SwiftProtobufNamer()
    for file in files {
      let priced = file.enums.compactMap { declared in
        EmittedPricedEnum(enumDescriptor: declared, namer: namer)
      }
      if priced.isEmpty {
        continue
      }
      try generatorOutputs.add(
        fileName: "Prices.\(file.baseName).generated.swift",
        contents: PriceFile(sourceFileName: file.name, pricedEnums: priced).swiftSource
      )
    }
  }
}
