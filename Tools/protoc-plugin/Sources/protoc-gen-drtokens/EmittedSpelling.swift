import Foundation

/// One property emitted onto an enum: what it is called, what it means, and the value each case
/// spells.
struct EmittedSpelling {
  let propertyName: String
  let documentation: String
  let readBackDocumentation: String
  let cases: [EmittedTokenValue]

  var swiftSource: String {
    var out = """

        /// \(documentation)
        ///
        /// Absent for a value with no declared spelling, which is what makes an unspellable value
        /// impossible to send rather than merely discouraged.
        public var \(propertyName): String? {
          switch self {

      """
    for spelling in cases {
      out += "    case .\(spelling.caseName): return \"\(spelling.token)\"\n"
    }
    out += """
          default: return nil
          }
        }

        /// \(readBackDocumentation)
        ///
        /// Nil for anything not in the contract, so an unrecognized spelling is rejected by the
        /// caller rather than silently becoming a default.
        public init?(\(propertyName): String) {
          switch \(propertyName) {

      """
    for spelling in cases {
      out += "    case \"\(spelling.token)\": self = .\(spelling.caseName)\n"
    }
    out += """
          default: return nil
          }
        }

      """
    return out
  }
}
