import ContractGeneration
import Foundation
import SwiftProtobuf
import SwiftProtobufPluginLibrary

/// Emits the endpoint table for every service: the verb, the path, and the audience each rpc
/// declared.
///
/// Two types come out of it, because the two consumers need different halves of the same fact. A
/// server registers route *templates* and dispatches on which rpc matched, so it gets a
/// CaseIterable enum carrying `template`. A client builds a *concrete* path and needs the compiler
/// to demand the ids that go in it, so it gets an enum whose cases carry the path parameters as
/// associated values.
///
/// Neither side writes a path. A string like "/requests/{requestId}/comments" typed into a router
/// and typed again into a client is one fact in two places, and the day they disagree the client
/// gets a 404 that looks like a server bug.
@main
struct EndpointTablePlugin: CodeGenerator {

  var version: String? { "1.0.0" }

  var projectURL: String? {
    "https://github.com/Different-Productions/differentrequests-proto"
  }

  var supportedFeatures: [Google_Protobuf_Compiler_CodeGeneratorResponse.Feature] {
    [.proto3Optional]
  }

  /// protoc surfaces the route options as decoded values only because they are declared here.
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
    for file in files where file.services.isEmpty == false {
      // Both enums are found through the options they type, so this generator names neither of
      // them. An option retyped in the schema is followed here rather than searched for by a
      // spelling that would have to be changed to match.
      let verbs = try EnumCaseNames(
        typing: contractRouteMethodExtension,
        reachableFrom: file,
        namer: namer
      )
      let audiences = try EnumCaseNames(
        typing: contractRouteAudienceExtension,
        reachableFrom: file,
        namer: namer
      )
      let planSurfaces = try EnumCaseNames(
        typing: contractPlanGateExtension,
        reachableFrom: file,
        namer: namer
      )
      var services: [EmittedService] = []
      for service in file.services {
        services.append(
          try EmittedService(
            service: service,
            namer: namer,
            verbs: verbs,
            audiences: audiences,
            planSurfaces: planSurfaces
          )
        )
      }
      try generatorOutputs.add(
        fileName: "ServiceEndpoints.generated.swift",
        contents: EndpointTableFile(sourceFileName: file.name, services: services).swiftSource
      )
    }
  }
}
