import Foundation

/// What a client calls: a concrete path, with the compiler demanding every id in it.
struct EmittedEndpointEnum {
  let serviceName: String
  let typePrefix: String
  let methods: [EmittedMethod]

  func swiftSource() -> String {
    casesSource() + pathSource() + rpcSource()
  }

  private func casesSource() -> String {
    var out = """

      /// One call to `\(serviceName)`, with the ids its path needs.
      ///
      /// A client builds this and reads `path`. Nothing spells a path itself, and an rpc whose
      /// path takes an id cannot be constructed without one.
      ///
      /// Ids are interpolated raw. Percent-encoding belongs to whoever assembles the URL —
      /// `URLComponents.path` does it correctly, and doing it here as well would double-encode.
      public enum \(typePrefix)\(serviceName)Endpoint: Sendable {

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
    return out
  }

  private func pathSource() -> String {
    var out = "\n  /// The path to call, relative to the API base URL.\n"
    out += "  public var path: String {\n    switch self {\n"

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
    return out
  }

  private func rpcSource() -> String {
    var out = """
          }
        }

        /// Which rpc this is, for anything that needs the verb or the audience.
        public var rpc: \(typePrefix)\(serviceName)RPC {
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
}
