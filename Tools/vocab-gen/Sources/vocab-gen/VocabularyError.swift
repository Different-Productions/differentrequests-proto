/// Every way vocab-gen refuses to emit. Each names the enum, and where the fault is
/// one value's, the value.
enum VocabularyError: Error {
  case descriptorUnreadable(path: String, reason: String)
  case descriptorUndecodable(path: String, reason: String)
  case protoFileAbsent(protoFileName: String, descriptorSetPath: String)
  case messageDeclared(protoFileName: String, messageName: String)
  case tokenAbsent(enumName: String, valueName: String)
  case tokenDuplicated(enumName: String, token: String, first: String, second: String)
  case caseNameDuplicated(enumName: String, caseName: String)
  case nothingEmitted(protoFileNames: [String])
  case directoryUncreatable(path: String, reason: String)
  case fileUnwritable(path: String, reason: String)

  var message: String {
    switch self {
    case .descriptorUnreadable(let path, let reason):
      return "cannot read the descriptor set at \(path): \(reason)"
    case .descriptorUndecodable(let path, let reason):
      return "cannot decode the descriptor set at \(path): \(reason)"
    case .protoFileAbsent(let protoFileName, let descriptorSetPath):
      return """
        \(protoFileName) is not in the descriptor set at \(descriptorSetPath). \
        Pass the name protoc recorded, which is the path relative to --proto_path.
        """
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
    case .directoryUncreatable(let path, let reason):
      return "cannot create \(path): \(reason)"
    case .fileUnwritable(let path, let reason):
      return "cannot write \(path): \(reason)"
    }
  }
}
