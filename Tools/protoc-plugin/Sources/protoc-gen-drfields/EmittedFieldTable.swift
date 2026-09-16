import ContractGeneration
import Foundation
import SwiftProtobufPluginLibrary

/// One message's field names, ready to be written as a Swift extension, plus a name for each arm
/// of every `oneof` it declares.
struct EmittedFieldTable {
  let typeName: String
  let fieldNames: [String]
  let oneofs: [EmittedOneof]

  /// Absent unless a field names the surface it decides.
  let gates: EmittedGates?

  /// Absent unless a field says how long its text may be.
  let textLimits: EmittedTextLimits?

  /// A message that declares no fields has no table to emit, so it is not one of these.
  init?(message: Descriptor, namer: SwiftProtobufNamer) throws {
    if message.fields.isEmpty {
      return nil
    }
    gates = try EmittedGates(message: message, namer: namer)
    textLimits = EmittedTextLimits(message: message, namer: namer)
    let name = namer.fullName(message: message)
    typeName = name
    fieldNames = message.fields.map(\.name)
    oneofs = message.realOneofs.map { oneof in
      EmittedOneof(oneof: oneof, messageTypeName: name, namer: namer)
    }
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
    for oneof in oneofs {
      out += oneof.swiftSource(messageTypeName: typeName)
    }
    if let gates {
      out += gates.swiftSource
    }
    if let textLimits {
      out += textLimits.swiftSource
    }
    return out
  }
}
