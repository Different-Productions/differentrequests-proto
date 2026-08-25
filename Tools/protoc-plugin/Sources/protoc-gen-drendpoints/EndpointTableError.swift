/// Why the endpoint table could not be emitted.
///
/// `CustomStringConvertible` because protoc reports a plugin's failure by calling
/// `String(describing:)` on whatever it throws.
enum EndpointTableError: Error, CustomStringConvertible {
  case incompleteRoute(service: String, method: String)

  var description: String {
    switch self {
    case .incompleteRoute(let service, let method):
      return """
        \(service).\(method) has no complete route — needs (route_method), (route_path) and \
        (route_audience). Fatal rather than defaulted: an rpc with no audience would be served \
        to anyone holding an app key, and one with no path would be served nowhere.
        """
    }
  }
}
