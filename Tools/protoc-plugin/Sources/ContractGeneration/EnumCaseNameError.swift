/// Why an enum-valued option could not be resolved to a Swift case.
///
/// `CustomStringConvertible` because protoc reports a plugin's failure by calling
/// `String(describing:)` on whatever it throws.
public enum EnumCaseNameError: Error, CustomStringConvertible {
  case optionAbsent(fieldName: String, protoFileName: String)
  case optionIsNotEnumTyped(fieldName: String)
  case valueAbsent(enumName: String, number: Int32)

  public var description: String {
    switch self {
    case .optionAbsent(let fieldName, let protoFileName):
      return """
        \(protoFileName) neither declares \(fieldName) nor imports the file that does. An option \
        can only be resolved where the file declaring it is reachable.
        """
    case .optionIsNotEnumTyped(let fieldName):
      return """
        \(fieldName) is not typed by an enum, so there is no set of values to resolve a number \
        against. This generator reads it as one.
        """
    case .valueAbsent(let enumName, let number):
      return """
        \(enumName) declares no value numbered \(number). The option holds a number this enum \
        has never assigned.
        """
    }
  }
}
