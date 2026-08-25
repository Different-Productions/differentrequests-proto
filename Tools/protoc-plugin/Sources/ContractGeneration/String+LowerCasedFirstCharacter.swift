import Foundation

extension String {
  /// `GetConfig` -> `getConfig`. The Swift case name for an rpc, which is its proto name with the
  /// first character lowered and nothing else touched.
  public var lowerCasedFirstCharacter: String {
    guard let first = first else {
      return self
    }
    return first.lowercased() + dropFirst()
  }
}
