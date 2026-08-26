import ContractGeneration
import Foundation
import SwiftProtobufPluginLibrary

/// One service's two generated enums: what a server routes on, and what a client calls.
struct EmittedService {
  let name: String
  let typePrefix: String
  let verbTypeName: String
  let audienceTypeName: String
  let methods: [EmittedMethod]

  init(
    service: ServiceDescriptor,
    namer: SwiftProtobufNamer,
    verbs: EnumCaseNames,
    audiences: EnumCaseNames
  ) throws {
    name = service.name
    typePrefix = service.file.options.swiftPrefix
    verbTypeName = verbs.typeName
    audienceTypeName = audiences.typeName
    methods = try service.methods.map { method in
      try EmittedMethod(method: method, verbs: verbs, audiences: audiences)
    }
  }

  var swiftSource: String {
    rpcEnumSource + pathParameterEnumSource + endpointEnumSource
  }

  /// Every `{brace}` name any rpc on this service declares, in the order they first appear.
  ///
  /// A router binds a path segment to a name and a handler reads the segment back by that name.
  /// Both are the template's, so both come from here rather than from a spelling typed at each
  /// read.
  private var pathParameterNames: [String] {
    var found: [String] = []
    for method in methods {
      for parameter in method.pathParameters where found.contains(parameter) == false {
        found.append(parameter)
      }
    }
    return found
  }

  private var pathParameterEnumSource: String {
    let names = pathParameterNames
    if names.isEmpty {
      return ""
    }
    var out = """

      /// Every `{brace}` name a path on `\(name)` declares.
      ///
      /// What a router binds a segment to, and what a handler reads it back by. Both are the
      /// template's own spelling, so neither is typed at the point it is used.
      public enum \(typePrefix)\(name)PathParameter {

      """
    for parameter in names {
      out += "  public static let \(parameter) = \"\(parameter)\"\n"
    }
    out += """
      }

      """
    return out
  }

  /// What a server routes on: every rpc, its template, and what it demands of a caller.
  private var rpcEnumSource: String {
    var out = """

      /// Every rpc on `\(name)`: the verb it answers, the path template it is registered
      /// at, and the credential it requires.
      ///
      /// A server builds its router from `allCases` and dispatches on the matched case, so an rpc
      /// added to the contract breaks an exhaustive switch until it is handled.
      public enum \(typePrefix)\(name)RPC: String, Sendable, CaseIterable {

      """

    for method in methods {
      out += "  case \(method.caseName) = \"\(method.protoName)\"\n"
    }

    out += switchSource(
      signature: "  /// The verb this rpc answers.\n  public var method: \(verbTypeName)",
      body: { ".\($0.verbCaseName)" }
    )

    out += switchSource(
      signature: """
          /// The path template, `{brace}` parameters included, as a router wants it.
          public var template: String
        """,
      body: { "\"\($0.pathTemplate)\"" }
    )

    out += switchSource(
      signature: """
          /// The minimum credential a caller must present. A server rejects anything weaker.
          public var audience: \(audienceTypeName)
        """,
      body: { ".\($0.audienceCaseName)" }
    )

    out += switchSource(
      signature: """
          /// The `{brace}` names in this rpc's template, in the order they appear.
          ///
          /// Empty for a path that takes none. Anything filling a template walks this rather than
          /// every name the service declares, so an rpc is never handed a parameter its own path
          /// does not have.
          public var pathParameters: [String]
        """,
      body: { method in
        let parameters = method.pathParameters
        if parameters.isEmpty {
          return "[]"
        }
        return "[\(parameters.map { "\"\($0)\"" }.joined(separator: ", "))]"
      }
    )

    out += "}\n"
    return out
  }

  /// What a client calls: a concrete path, with the compiler demanding every id in it.
  private var endpointEnumSource: String {
    var out = """

      /// One call to `\(name)`, with the ids its path needs.
      ///
      /// A client builds this and reads `path`. Nothing spells a path itself, and an rpc whose
      /// path takes an id cannot be constructed without one.
      ///
      /// Ids are interpolated raw. Percent-encoding belongs to whoever assembles the URL —
      /// `URLComponents.path` does it correctly, and doing it here as well would double-encode.
      public enum \(typePrefix)\(name)Endpoint: Sendable {

      """

    for method in methods {
      let parameters = method.pathParameters
      if parameters.isEmpty {
        out += "  case \(method.caseName)\n"
      } else {
        let labels = parameters.map { "\($0): String" }.joined(separator: ", ")
        out += "  case \(method.caseName)(\(labels))\n"
      }
    }

    out += "\n  /// The path to call, relative to the API base URL.\n  public var path: String {\n    switch self {\n"

    for method in methods {
      let parameters = method.pathParameters
      if parameters.isEmpty {
        out += "    case .\(method.caseName): return \"\(method.pathTemplate)\"\n"
      } else {
        let bindings = parameters.map { "let \($0)" }.joined(separator: ", ")
        var interpolated = method.pathTemplate
        for parameter in parameters {
          interpolated = interpolated.replacingOccurrences(
            of: "{\(parameter)}",
            with: "\\(\(parameter))"
          )
        }
        out += "    case .\(method.caseName)(\(bindings)): return \"\(interpolated)\"\n"
      }
    }

    out += """
          }
        }

        /// Which rpc this is, for anything that needs the verb or the audience.
        public var rpc: \(typePrefix)\(name)RPC {
          switch self {

      """

    for method in methods {
      let parameters = method.pathParameters
      if parameters.isEmpty {
        out += "    case .\(method.caseName): return .\(method.caseName)\n"
      } else {
        // Every associated value is bound and used, so nothing is discarded.
        let bindings = parameters.map { "let \($0)" }.joined(separator: ", ")
        let used = parameters.map { "_ = \($0)" }.joined(separator: "; ")
        out += "    case .\(method.caseName)(\(bindings)): \(used); return .\(method.caseName)\n"
      }
    }

    out += """
          }
        }
      }

      """

    return out
  }

  private func switchSource(signature: String, body: (EmittedMethod) -> String) -> String {
    var out = "\n\(signature) {\n    switch self {\n"
    for method in methods {
      out += "    case .\(method.caseName): return \(body(method))\n"
    }
    out += "    }\n  }\n"
    return out
  }
}
