/// Why an enum-valued option could not be resolved to a Swift case.
///
/// `CustomStringConvertible` because protoc reports a plugin's failure by calling
/// `String(describing:)` on whatever it throws.
public enum EnumCaseNameError: Error, CustomStringConvertible {
  case enumAbsent(enumName: String)
  case valueAbsent(enumName: String, number: Int32)

  public var description: String {
    switch self {
    case .enumAbsent(let enumName):
      return """
        no enum named \(enumName) is declared by this file or imported by it. An option \
        typed by an enum can only be resolved where that enum is reachable.
        """
    case .valueAbsent(let enumName, let number):
      return """
        \(enumName) declares no value numbered \(number). The option holds a number this \
        enum has never assigned.
        """
    }
  }
}
