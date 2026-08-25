import ContractGeneration
import Foundation
import SwiftProtobufPluginLibrary

/// One message's field names, ready to be written as a Swift extension.
struct EmittedFieldTable {
  let typeName: String
  let fieldNames: [String]

  /// A message that declares no fields has no table to emit, so it is not one of these.
  init?(message: Descriptor, namer: SwiftProtobufNamer) {
    if message.fields.isEmpty {
      return nil
    }
    typeName = namer.fullName(message: message)
    fieldNames = message.fields.map(\.name)
  }

  var swiftSource: String {
    var out = """

      extension \(typeName) {
        /// This message's field names, as the schema spells them. What a query key or a form field
        /// has to be called.
        public enum Field {

      """
    for name in fieldNames {
      out += "    public static let \(name.lowerCamelCased) = \"\(name)\"\n"
    }
    out += """
        }
      }

      """
    return out
  }
}
