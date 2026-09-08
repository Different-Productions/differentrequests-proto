import Foundation

/// One property emitted onto an enum: what it is called, what it means, and the value each case
/// spells.
struct EmittedSpelling {
  let propertyName: String
  let documentation: String
  let kind: SpelledStringKind
  let cases: [EmittedTokenValue]

  var swiftSource: String {
    switch kind {
    case .identifier(let readBackDocumentation):
      return identifierSource(readBackDocumentation: readBackDocumentation)
    case .prose(let whenUnrecognized):
      return proseSource(whenUnrecognized: whenUnrecognized)
    }
  }

  /// A spelling something outside Swift sends: optional, because a value may decline to declare
  /// one, and readable back, because something outside Swift sends it in.
  private func identifierSource(readBackDocumentation: String) -> String {
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

  /// Prose a person reads: total, so a caller drawing it is never handed nothing, and with no
  /// initializer, because nothing parses a word off a screen.
  ///
  /// The switch carries no `default`, so a value added to the schema without a label stops this
  /// package compiling at the arm it is missing.
  private func proseSource(whenUnrecognized: String) -> String {
    var out = """

        /// \(documentation)
        ///
        /// Total: every value of this enum declares one, so there is nothing to fall back to and
        /// no caller has to invent a word.
        public var \(propertyName): String {
          switch self {

      """
    for spelling in cases {
      out += "    case .\(spelling.caseName): return \"\(spelling.token)\"\n"
    }
    out += """
          case .UNRECOGNIZED: return "\(whenUnrecognized)"
          }
        }

      """
    return out
  }
}
