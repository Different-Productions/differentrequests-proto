import Foundation

extension String {
  /// The snake_case wire name as a Swift constant name. A spelling choice of this generator, not a
  /// reading of the schema — the wire name itself is what the constant holds.
  public var lowerCamelCased: String {
    let words = split(separator: "_").map(String.init)
    guard let first = words.first else {
      return self
    }
    return first + words.dropFirst().map { $0.capitalized }.joined()
  }
}
