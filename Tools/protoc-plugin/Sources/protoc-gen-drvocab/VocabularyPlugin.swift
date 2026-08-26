import ContractGeneration
import Foundation
import SwiftProtobuf
import SwiftProtobufPluginLibrary

/// Emits one Swift enum per vocabulary enum: a case per value, carrying the exact token the value
/// takes when it leaves Swift.
///
/// protoc emits Int-backed enums, so a value whose contract *is* its spelling — an HTTP header, an
/// authorization scheme, a media type — cannot carry that spelling in the generated enum. Every one
/// of them was a literal in the server and the SDK both until it was declared in the proto, and
/// this is what reads it back out.
///
/// One output directory rather than a routed set, because this package emits one module.
/// LiminalWallet's vocab-gen routes by `(audience)` because three modules in one repository share
/// its vocabulary; here the server and the SDK both link `DifferentRequestsProtos`, so an audience
/// would be an option with one value and nothing to decide.
///
/// Output is a pure function of the descriptors protoc hands over: enums in declaration order,
/// values in declaration order, no timestamps and no host paths.
@main
struct VocabularyPlugin: CodeGenerator {

  var version: String? { "1.0.0" }

  var projectURL: String? {
    "https://github.com/Different-Productions/differentrequests-proto"
  }

  var supportedFeatures: [Google_Protobuf_Compiler_CodeGeneratorResponse.Feature] {
    [.proto3Optional]
  }

  /// protoc surfaces `(token)` as a decoded value only because it is declared here.
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
    var emittedAnything = false

    for file in files {
      if let message = file.messages.first {
        throw VocabularyError.messageDeclared(
          protoFileName: file.name,
          messageName: message.name
        )
      }
      for enumDescriptor in file.enums {
        let emitted = try emittedEnum(
          for: enumDescriptor,
          protoFileName: file.name,
          namer: namer
        )
        try generatorOutputs.add(
          fileName: "Vocabulary/\(emitted.fileName)",
          contents: emitted.swiftSource
        )
        emittedAnything = true
      }
    }

    if emittedAnything == false {
      throw VocabularyError.nothingEmitted(protoFileNames: files.map(\.name))
    }
  }

  private func emittedEnum(
    for enumDescriptor: EnumDescriptor,
    protoFileName: String,
    namer: SwiftProtobufNamer
  ) throws -> EmittedEnum {
    let name = namer.relativeName(enum: enumDescriptor)

    var cases: [EmittedCase] = []
    var valueNameForToken: [String: String] = [:]
    var valueNameForCaseName: [String: String] = [:]
    for value in enumDescriptor.values {
      guard let token = value.options.getExtensionValue(ext: DRExtensions_token) else {
        throw VocabularyError.tokenAbsent(enumName: name, valueName: value.name)
      }
      if let owner = valueNameForToken[token] {
        throw VocabularyError.tokenDuplicated(
          enumName: name,
          token: token,
          first: owner,
          second: value.name
        )
      }
      valueNameForToken[token] = value.name
      let caseName = namer.relativeName(enumValue: value)
      if let owner = valueNameForCaseName[caseName] {
        throw VocabularyError.caseNameDuplicated(
          enumName: name,
          caseName: "\(caseName) (from \(owner) and \(value.name))"
        )
      }
      valueNameForCaseName[caseName] = value.name
      cases.append(
        EmittedCase(
          name: caseName,
          token: token,
          documentation: documentation(for: value)
        )
      )
    }

    return EmittedEnum(
      name: name,
      documentation: documentation(for: enumDescriptor),
      cases: cases,
      protoFileName: protoFileName
    )
  }

  private func documentation(for source: any ProvidesSourceCodeLocation) -> [String] {
    let comment = source.protoSourceComments(commentPrefix: "///", leadingDetachedPrefix: nil)
    var lines: [String] = []
    for line in comment.split(separator: "\n", omittingEmptySubsequences: false) {
      let trimmed = String(line).trimmingTrailingWhitespace
      if trimmed.isEmpty {
        continue
      }
      lines.append(trimmed)
    }
    return lines
  }
}
