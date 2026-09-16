import ContractGeneration
import Foundation
import SwiftProtobufPluginLibrary

/// A message whose text fields say how long they may be, and the numbers that answers with.
///
/// Both sides need the same number for different reasons: the server refuses anything longer, and
/// the SDK stops somebody at the keyboard before they lose what they wrote. Written in each
/// repository it is one limit with two numbers, and the day they differ a person is refused for a
/// length their own composer said was fine — which is what was happening, with the server holding
/// every number and the SDK holding none.
struct EmittedTextLimits {
  let messageTypeName: String
  let limits: [EmittedTextLimit]

  /// A message where no field declares a limit has none to emit, so it is not one of these.
  init?(message: Descriptor, namer: SwiftProtobufNamer) {
    var found: [EmittedTextLimit] = []

    for field in message.fields {
      let declared = field.options.getExtensionValue(ext: DRExtensions_max_characters)
      guard let declared, declared > 0 else {
        continue
      }
      found.append(
        EmittedTextLimit(
          propertyName: namer.messagePropertyNames(
            field: field,
            prefixed: "",
            includeHasAndClear: false
          ).name,
          characters: declared
        )
      )
    }

    guard found.isEmpty == false else {
      return nil
    }
    messageTypeName = namer.fullName(message: message)
    limits = found
  }

  var swiftSource: String {
    var out = """

      extension \(messageTypeName) {
        /// The longest each of this message's text fields may be, in characters, counted the way a
        /// person counts.
        ///
        /// The server refuses anything longer and the SDK counts against the same number, so a
        /// composer stops somebody where the refusal would have.
        public enum TextLimit {

      """
    for limit in limits {
      out += "    public static let \(limit.propertyName) = \(limit.characters)\n"
    }
    out += """
        }
      }

      """
    return out
  }
}
