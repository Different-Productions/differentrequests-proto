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

  /// An rpc with an incomplete route is refused rather than defaulted: one with no audience would
  /// otherwise be served to anyone holding an app key, and one with no path would be served
  /// nowhere.
  init(method: MethodDescriptor, verbs: EnumCaseNames, audiences: EnumCaseNames) throws {
    guard
      let verb = method.options.getExtensionValue(ext: contractRouteMethodExtension),
      let path = method.options.getExtensionValue(ext: contractRoutePathExtension),
      let audience = method.options.getExtensionValue(ext: contractRouteAudienceExtension)
    else {
      throw EndpointTableError.incompleteRoute(
        service: method.service.name,
        method: method.name
      )
    }
    protoName = method.name
    caseName = method.name.lowerCasedFirstCharacter
    verbCaseName = try verbs.caseName(forValue: verb)
    pathTemplate = path
    audienceCaseName = try audiences.caseName(forValue: audience)
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
