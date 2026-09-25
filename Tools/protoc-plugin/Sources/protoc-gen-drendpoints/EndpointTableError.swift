/// Why the endpoint table could not be emitted.
///
/// `CustomStringConvertible` because protoc reports a plugin's failure by calling
/// `String(describing:)` on whatever it throws.
enum EndpointTableError: Error, CustomStringConvertible {
  case incompleteRoute(service: String, method: String)
  case answerlessRPC(service: String, method: String)
  case oneAnswerForTwoRPCs(service: String, answer: String, first: String, second: String)

  var description: String {
    switch self {
    case .incompleteRoute(let service, let method):
      return """
        \(service).\(method) has no complete route — needs (route_method), (route_path), \
        (route_audience), (route_allowance) and a non-empty (route_label). Fatal rather than \
        defaulted: an rpc with no audience would be served to anyone holding an app key, one with \
        no path would be served nowhere, one with no allowance would be answered without being \
        counted, and one with no label would be listed by a name only its authors can read.
        """
    case .answerlessRPC(let service, let method):
      return """
        \(service).\(method) declares no response message, so there is no type for a server to \
        register its handler by.
        """
    case .oneAnswerForTwoRPCs(let service, let answer, let first, let second):
      return """
        \(service).\(first) and \(service).\(second) both return \(answer). A response message \
        names the one rpc it answers, so two rpcs sharing one leaves a server no way to say which \
        handler it is registering. Give each its own response message.
        """
    }
  }
}
