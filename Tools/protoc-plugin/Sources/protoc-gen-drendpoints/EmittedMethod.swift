import ContractGeneration
import Foundation
import SwiftProtobufPluginLibrary

/// One rpc, resolved to everything the generated table says about it.
struct EmittedMethod {
  let protoName: String
  let caseName: String
  let verbCaseName: String
  let pathTemplate: String
  let audienceCaseName: String
  let allowanceCaseName: String

  /// The generated Swift type this rpc returns.
  ///
  /// What makes the pairing of an rpc to the code answering it checkable: a handler is registered
  /// by the message it returns, and that message names one rpc.
  let answerTypeName: String

  /// Absent for an rpc every plan includes. Unlike a route, saying nothing is a complete answer
  /// here — it is the same statement as naming no surface.
  let planGateCaseName: String?

  /// An rpc with an incomplete route is refused rather than defaulted: one with no audience would
  /// otherwise be served to anyone holding an app key, one with no path would be served nowhere,
  /// and one with no allowance would be answered without being counted.
  init(
    method: MethodDescriptor,
    namer: SwiftProtobufNamer,
    verbs: EnumCaseNames,
    audiences: EnumCaseNames,
    allowances: EnumCaseNames,
    planSurfaces: EnumCaseNames
  ) throws {
    guard
      let verb = method.options.getExtensionValue(ext: DRExtensions_route_method),
      let path = method.options.getExtensionValue(ext: DRExtensions_route_path),
      let audience = method.options.getExtensionValue(ext: DRExtensions_route_audience),
      let allowance = method.options.getExtensionValue(ext: DRExtensions_route_allowance)
    else {
      throw EndpointTableError.incompleteRoute(
        service: method.service.name,
        method: method.name
      )
    }
    guard let answer = method.outputType else {
      throw EndpointTableError.answerlessRPC(
        service: method.service.name,
        method: method.name
      )
    }
    protoName = method.name
    caseName = method.name.lowerCasedFirstCharacter
    verbCaseName = try verbs.caseName(forValue: Int32(verb.rawValue))
    pathTemplate = path
    audienceCaseName = try audiences.caseName(forValue: Int32(audience.rawValue))
    allowanceCaseName = try allowances.caseName(forValue: Int32(allowance.rawValue))
    answerTypeName = namer.fullName(message: answer)

    if let gate = method.options.getExtensionValue(ext: DRExtensions_plan_gate) {
      planGateCaseName = try planSurfaces.caseName(forValue: Int32(gate.rawValue))
    } else {
      planGateCaseName = nil
    }
  }

  /// The `{brace}` parameters in the template, in the order they appear — which is the order the
  /// generated case takes them, so a caller reading the path reads the arguments.
  var pathParameters: [String] {
    var parameters: [String] = []
    var remaining = Substring(pathTemplate)
    while let open = remaining.firstIndex(of: "{") {
      guard let close = remaining[open...].firstIndex(of: "}") else {
        break
      }
      let name = remaining[remaining.index(after: open)..<close]
      parameters.append(String(name))
      remaining = remaining[remaining.index(after: close)...]
    }
    return parameters
  }
}
