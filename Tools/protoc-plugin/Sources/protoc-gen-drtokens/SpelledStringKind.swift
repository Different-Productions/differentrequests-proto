import Foundation

/// What kind of string an enum value spells, which decides the shape of the Swift emitted for it.
///
/// The two are not variations on one property. An identifier is matched on by something outside
/// Swift, so it is read back and a value may decline to declare one; prose is drawn for a person,
/// is never parsed, and every value of the enum declares one so the reader is never handed nothing
/// to draw.
enum SpelledStringKind {
  /// A string something outside Swift sends or matches on: a URL token, an HTTP verb, a header
  /// name. Emitted optional, with an initializer that reads one back.
  case identifier(readBackDocumentation: String)

  /// A string a person reads. Emitted total, with no initializer.
  ///
  /// - Parameter whenUnrecognized: the word for a value this build does not know, which is the
  ///   label the enum's zero value declares.
  case prose(whenUnrecognized: String)
}
