import ContractGeneration
import Foundation
import SwiftProtobuf
import SwiftProtobufPluginLibrary

/// Emits, for every enum value carrying a `(url_token)` option, the spelling it takes in a URL and
/// an initializer that reads one back.
///
/// The client that writes `?sort=top` and the server that matches on it have to agree, and the only
/// way for that to be one fact is for both to read it from the schema. Hand-typed on either side it
/// is a copy, and the day they disagree the server answers a default nobody asked for.
///
/// A value with no token has no spelling and cannot be sent, which is what keeps a zero sentinel
/// out of a query string.
@main
struct URLTokenPlugin: CodeGenerator {

  var version: String? { "1.0.0" }

  var projectURL: String? {
    "https://github.com/Different-Productions/differentrequests-proto"
  }

  var supportedFeatures: [Google_Protobuf_Compiler_CodeGeneratorResponse.Feature] {
    [.proto3Optional]
  }

  /// protoc surfaces `(url_token)` as a decoded value only because it is declared here.
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
      let spelled = file.enums.compactMap { declared in
        EmittedTokenEnum(enumDescriptor: declared, namer: namer)
      }
      if spelled.isEmpty {
        continue
      }
      try generatorOutputs.add(
        fileName: "URLTokens.\(file.baseName).generated.swift",
        contents: URLTokenFile(sourceFileName: file.name, spelledEnums: spelled).swiftSource
      )
    }
  }
}
