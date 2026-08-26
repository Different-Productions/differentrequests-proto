import ContractGeneration
import Foundation
import SwiftProtobuf
import SwiftProtobufPluginLibrary

/// Emits, for every enum value that declares a spelling, the string it becomes and an initializer
/// that reads one back.
///
/// Two options declare one. `(url_token)` is how a value is written inside a URL this API serves;
/// `(token)` is the exact string a value becomes when it leaves Swift for anything else — an HTTP
/// verb, a header name. Each becomes its own property, and an enum may carry both.
///
/// The client that writes `?sort=top` and the server that matches on it have to agree, and the only
/// way for that to be one fact is for both to read it from the schema. Hand-typed on either side it
/// is a copy, and the day they disagree the server answers a default nobody asked for.
///
/// A value with no spelling cannot be sent, which is what keeps a zero sentinel off the wire.
@main
struct SpellingPlugin: CodeGenerator {

  var version: String? { "1.0.0" }

  var projectURL: String? {
    "https://github.com/Different-Productions/differentrequests-proto"
  }

  var supportedFeatures: [Google_Protobuf_Compiler_CodeGeneratorResponse.Feature] {
    [.proto3Optional]
  }

  /// protoc surfaces the spelling options as decoded values only because they are declared here.
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
        fileName: "Spellings.\(file.baseName).generated.swift",
        contents: SpellingFile(sourceFileName: file.name, spelledEnums: spelled).swiftSource
      )
    }
  }
}
