/// One Swift case: the token it carries and the doc comment lines above it.
struct EmittedCase {
  let name: String
  let token: String
  let documentation: [String]

  /// The token as a Swift string literal, byte for byte.
  var stringLiteral: String {
    var escaped = ""
    for character in token {
      if character == "\\" {
        escaped.append("\\\\")
      } else if character == "\"" {
        escaped.append("\\\"")
      } else {
        escaped.append(character)
      }
    }
    return "\"\(escaped)\""
  }
}
