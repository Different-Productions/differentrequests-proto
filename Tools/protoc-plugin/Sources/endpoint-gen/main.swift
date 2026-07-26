import Foundation

// Emits the endpoint table for every service in a .proto file: the verb, the path, and the
// audience each rpc declared.
//
// Two types come out of it, because the two consumers need different halves of the same fact.
// A server registers route *templates* and dispatches on which rpc matched, so it gets a
// CaseIterable enum carrying `template`. A client builds a *concrete* path and needs the
// compiler to demand the ids that go in it, so it gets an enum whose cases carry the path
// parameters as associated values.
//
// Neither side writes a path. A string like "/requests/{requestId}/comments" typed into a
// router and typed again into a client is one fact in two places, and the day they disagree
// the client gets a 404 that looks like a server bug.
//
// A pure parser over the proto text, taking no dependency on protoc or swift-protobuf:
// swift-protobuf generates no service code at all, so there is no descriptor to read.

struct Method {
  let name: String
  let verb: String
  let pathTemplate: String
  let audience: String

  /// The `{brace}` parameters in the template, in the order they appear — which is the order
  /// the generated case takes them, so a caller reading the path reads the arguments.
  var pathParameters: [String] {
    var parameters: [String] = []
    var remaining = Substring(pathTemplate)
    while let open = remaining.firstIndex(of: "{") {
      guard let close = remaining[open...].firstIndex(of: "}") else { break }
      let name = remaining[remaining.index(after: open)..<close]
      parameters.append(String(name))
      remaining = remaining[remaining.index(after: close)...]
    }
    return parameters
  }
}

struct Service {
  let name: String
  let methods: [Method]
}

enum GeneratorError: Error, CustomStringConvertible {
  case usage
  case unreadable(String)
  case noPackage(String)
  case incompleteRoute(service: String, method: String)

  var description: String {
    switch self {
    case .usage:
      return "usage: endpoint-gen <input.proto> <output-directory>"
    case .unreadable(let path):
      return "cannot read \(path)"
    case .noPackage(let path):
      return "\(path) declares no package"
    case .incompleteRoute(let service, let method):
      // Fatal rather than defaulted: an rpc with no audience would otherwise be served to
      // anyone holding an app key, and an rpc with no path would be served nowhere.
      return "\(service).\(method) has no complete (route) option — needs method, path, audience"
    }
  }
}

func parse(_ text: String, path: String) throws -> (package: String, prefix: String, services: [Service]) {
  var package = ""
  var prefix = ""
  var services: [Service] = []

  var currentService: String?
  var currentMethods: [Method] = []
  var pendingName: String?
  var pendingVerb: String?
  var pendingPath: String?
  var pendingAudience: String?

  // Depth relative to the enclosing `service` block. Tracked rather than matching a bare
  // closing brace, because every rpc carrying an option closes with one and that is not the
  // end of the service.
  var depth = 0

  for rawLine in text.split(separator: "\n", omittingEmptySubsequences: false) {
    let line = rawLine.trimmingCharacters(in: .whitespaces)

    if depth == 0 {
      if line.hasPrefix("option swift_prefix") {
        if let first = line.firstIndex(of: "\""), let last = line.lastIndex(of: "\""), first < last {
          prefix = String(line[line.index(after: first)..<last])
        }
      } else if line.hasPrefix("package ") {
        package = line
          .dropFirst("package ".count)
          .trimmingCharacters(in: CharacterSet(charactersIn: " ;"))
      } else if line.hasPrefix("service ") {
        currentService = line
          .dropFirst("service ".count)
          .trimmingCharacters(in: CharacterSet(charactersIn: " {"))
        currentMethods = []
        depth = 1
      }
      continue
    }

    guard let service = currentService else { continue }

    if line.hasPrefix("rpc ") {
      let afterKeyword = line.dropFirst("rpc ".count)
      if let parenIndex = afterKeyword.firstIndex(of: "(") {
        pendingName = afterKeyword[..<parenIndex].trimmingCharacters(in: .whitespaces)
        pendingVerb = nil
        pendingPath = nil
        pendingAudience = nil
      }
    } else if line.hasPrefix("method:") {
      pendingVerb = value(after: "method:", in: line)
    } else if line.hasPrefix("path:") {
      pendingPath = value(after: "path:", in: line).trimmingCharacters(in: CharacterSet(charactersIn: "\""))
    } else if line.hasPrefix("audience:") {
      pendingAudience = value(after: "audience:", in: line)
    }

    let depthBefore = depth
    depth += line.filter { $0 == "{" }.count
    depth -= line.filter { $0 == "}" }.count

    // An rpc block just closed.
    if depthBefore > depth, depth == 1, let name = pendingName {
      guard let verb = pendingVerb, let template = pendingPath, let audience = pendingAudience else {
        throw GeneratorError.incompleteRoute(service: service, method: name)
      }
      currentMethods.append(
        Method(name: name, verb: verb, pathTemplate: template, audience: audience)
      )
      pendingName = nil
    }

    if depth == 0 {
      if currentMethods.isEmpty == false {
        services.append(Service(name: service, methods: currentMethods))
      }
      currentService = nil
      currentMethods = []
    }
  }

  if package.isEmpty {
    throw GeneratorError.noPackage(path)
  }

  return (package, prefix, services)
}

func value(after prefix: String, in line: String) -> String {
  line
    .dropFirst(prefix.count)
    .trimmingCharacters(in: CharacterSet(charactersIn: " ;"))
}

/// `HTTP_METHOD_GET` -> `get`, `AUDIENCE_END_USER` -> `endUser`: the case names
/// protoc-gen-swift generates for those values. Derived rather than mapped, so a new value
/// needs no change here.
func swiftEnumCase(_ protoValue: String, strippingPrefix prefix: String) -> String {
  let withoutPrefix = protoValue.hasPrefix(prefix) ? String(protoValue.dropFirst(prefix.count)) : protoValue
  let words = withoutPrefix.split(separator: "_").map { $0.lowercased() }
  guard let first = words.first else { return withoutPrefix.lowercased() }
  return first + words.dropFirst().map { $0.capitalized }.joined()
}

func lowerCamel(_ name: String) -> String {
  guard let first = name.first else { return name }
  return first.lowercased() + name.dropFirst()
}

func render(package: String, prefix: String, services: [Service], sourceFile: String) -> String {
  var out = """
    // DO NOT EDIT.
    //
    // Generated by endpoint-gen from \(sourceFile). Run Scripts/generate.sh.

    """

  for service in services {
    out += renderRPCEnum(service, prefix: prefix)
    out += renderEndpointEnum(service, prefix: prefix)
  }

  return out
}

/// What a server routes on: every rpc, its template, and what it demands of a caller.
func renderRPCEnum(_ service: Service, prefix: String) -> String {
  var out = """

    /// Every rpc on `\(service.name)`: the verb it answers, the path template it is registered
    /// at, and the credential it requires.
    ///
    /// A server builds its router from `allCases` and dispatches on the matched case, so an rpc
    /// added to the contract breaks an exhaustive switch until it is handled.
    public enum \(prefix)\(service.name)RPC: String, Sendable, CaseIterable {

    """

  for method in service.methods {
    out += "  case \(lowerCamel(method.name)) = \"\(method.name)\"\n"
  }

  out += renderSwitch(
    service: service,
    signature: "  /// The verb this rpc answers.\n  public var method: \(prefix)HttpMethod",
    body: { ".\(swiftEnumCase($0.verb, strippingPrefix: "HTTP_METHOD_"))" }
  )

  out += renderSwitch(
    service: service,
    signature: """
        /// The path template, `{brace}` parameters included, as a router wants it.
        public var template: String
      """,
    body: { "\"\($0.pathTemplate)\"" }
  )

  out += renderSwitch(
    service: service,
    signature: """
        /// The minimum credential a caller must present. A server rejects anything weaker.
        public var audience: \(prefix)Audience
      """,
    body: { ".\(swiftEnumCase($0.audience, strippingPrefix: "AUDIENCE_"))" }
  )

  out += "}\n"
  return out
}

/// What a client calls: a concrete path, with the compiler demanding every id in it.
func renderEndpointEnum(_ service: Service, prefix: String) -> String {
  var out = """

    /// One call to `\(service.name)`, with the ids its path needs.
    ///
    /// A client builds this and reads `path`. Nothing spells a path itself, and an rpc whose
    /// path takes an id cannot be constructed without one.
    ///
    /// Ids are interpolated raw. Percent-encoding belongs to whoever assembles the URL —
    /// `URLComponents.path` does it correctly, and doing it here as well would double-encode.
    public enum \(prefix)\(service.name)Endpoint: Sendable {

    """

  for method in service.methods {
    let parameters = method.pathParameters
    if parameters.isEmpty {
      out += "  case \(lowerCamel(method.name))\n"
    } else {
      let labels = parameters.map { "\($0): String" }.joined(separator: ", ")
      out += "  case \(lowerCamel(method.name))(\(labels))\n"
    }
  }

  out += "\n  /// The path to call, relative to the API base URL.\n  public var path: String {\n    switch self {\n"

  for method in service.methods {
    let parameters = method.pathParameters
    let caseName = lowerCamel(method.name)
    if parameters.isEmpty {
      out += "    case .\(caseName): return \"\(method.pathTemplate)\"\n"
    } else {
      let bindings = parameters.map { "let \($0)" }.joined(separator: ", ")
      var interpolated = method.pathTemplate
      for parameter in parameters {
          interpolated = interpolated.replacingOccurrences(
          of: "{\(parameter)}",
          with: "\\(\(parameter))"
        )
      }
      out += "    case .\(caseName)(\(bindings)): return \"\(interpolated)\"\n"
    }
  }

  out += """
        }
      }

      /// Which rpc this is, for anything that needs the verb or the audience.
      public var rpc: \(prefix)\(service.name)RPC {
        switch self {

    """

  for method in service.methods {
    let parameters = method.pathParameters
    let caseName = lowerCamel(method.name)
    if parameters.isEmpty {
      out += "    case .\(caseName): return .\(caseName)\n"
    } else {
      // Every associated value is bound and used, so nothing is discarded.
      let bindings = parameters.map { "let \($0)" }.joined(separator: ", ")
      let used = parameters.map { "_ = \($0)" }.joined(separator: "; ")
      out += "    case .\(caseName)(\(bindings)): \(used); return .\(caseName)\n"
    }
  }

  out += """
        }
      }
    }

    """

  return out
}

func renderSwitch(service: Service, signature: String, body: (Method) -> String) -> String {
  var out = "\n\(signature) {\n    switch self {\n"
  for method in service.methods {
    out += "    case .\(lowerCamel(method.name)): return \(body(method))\n"
  }
  out += "    }\n  }\n"
  return out
}

let arguments = CommandLine.arguments
guard arguments.count == 3 else {
  FileHandle.standardError.write(Data((GeneratorError.usage.description + "\n").utf8))
  exit(1)
}

let inputPath = arguments[1]
let outputDirectory = arguments[2]

do {
  guard let text = try? String(contentsOfFile: inputPath, encoding: .utf8) else {
    throw GeneratorError.unreadable(inputPath)
  }

  let sourceFile = (inputPath as NSString).lastPathComponent
  let parsed = try parse(text, path: inputPath)
  let rendered = render(
    package: parsed.package,
    prefix: parsed.prefix,
    services: parsed.services,
    sourceFile: sourceFile
  )

  let outputPath = (outputDirectory as NSString)
    .appendingPathComponent("ServiceEndpoints.generated.swift")
  try rendered.write(toFile: outputPath, atomically: true, encoding: .utf8)
  print("endpoint-gen: wrote \(outputPath)")
} catch {
  FileHandle.standardError.write(Data(("endpoint-gen: \(error)\n").utf8))
  exit(1)
}
