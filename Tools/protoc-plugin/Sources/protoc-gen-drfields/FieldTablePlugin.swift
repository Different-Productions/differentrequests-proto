import ContractGeneration
import Foundation
import SwiftProtobuf
import SwiftProtobufPluginLibrary

/// Emits, for every message, the names of its fields exactly as the schema spells them.
///
/// A server reading `?cursor=` and a client writing it are both naming a field of a request
/// message. Typed as a literal on either side that is a copy of the schema, and the copy is what
/// drifts: a field renamed in the contract leaves a server still reading the old key and answering
/// a default.
///
/// So the names come from here. `DRListRequestsRequest.Field.cursor` is the same string the schema
/// declares, and a field that no longer exists stops compiling rather than quietly never matching.
///
/// protoc-gen-swift emits Swift property names; the wire name is what a query key has to be, and
/// that is what this emits.
@main
struct FieldTablePlugin: CodeGenerator {

  var version: String? { "1.0.0" }

  var projectURL: String? {
    "https://github.com/Different-Productions/differentrequests-proto"
  }

  var supportedFeatures: [Google_Protobuf_Compiler_CodeGeneratorResponse.Feature] {
    [.proto3Optional]
  }

  func generate(
    files: [FileDescriptor],
    parameter: any CodeGeneratorParameter,
    protoCompilerContext: any ProtoCompilerContext,
    generatorOutputs: any GeneratorOutputs
  ) throws {
    let namer = SwiftProtobufNamer()
    for file in files {
      let tables = file.messages.compactMap { message in
        EmittedFieldTable(message: message, namer: namer)
      }
      if tables.isEmpty {
        continue
      }
      try generatorOutputs.add(
        fileName: "Fields.\(file.baseName).generated.swift",
        contents: FieldTableFile(sourceFileName: file.name, tables: tables).swiftSource
      )
    }
  }
}
