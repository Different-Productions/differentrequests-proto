/// Every way the vocabulary generator refuses to emit. Each names the enum, and where the fault is
/// one value's, the value.
///
/// `CustomStringConvertible` because protoc reports a plugin's failure by calling
/// `String(describing:)` on whatever it throws.
enum VocabularyError: Error, CustomStringConvertible {
  case messageDeclared(protoFileName: String, messageName: String)
  case tokenAbsent(enumName: String, valueName: String)
  case tokenDuplicated(enumName: String, token: String, first: String, second: String)
  case caseNameDuplicated(enumName: String, caseName: String)
  case nothingEmitted(protoFileNames: [String])

  var description: String {
    switch self {
    case .messageDeclared(let protoFileName, let messageName):
      return """
        \(protoFileName) declares message \(messageName). The vocabulary is enums \
        only; an enum nested in a message would be skipped without anything saying so.
        """
    case .tokenAbsent(let enumName, let valueName):
      return """
        \(enumName).\(valueName) carries no (token). The token is the contract; \
        there is no default to fall back to.
        """
    case .tokenDuplicated(let enumName, let token, let first, let second):
      return """
        \(enumName).\(first) and \(enumName).\(second) both carry the token \
        "\(token)". Two Swift cases cannot share one raw value.
        """
    case .caseNameDuplicated(let enumName, let caseName):
      return """
        enum \(enumName) produces the Swift case name \(caseName) twice. Rename one \
        of the proto values.
        """
    case .nothingEmitted(let protoFileNames):
      return """
        no enums were found in \(protoFileNames.joined(separator: ", ")). A generator \
        that emits nothing is the failure this generator exists to remove.
        """
    }
  }
}
