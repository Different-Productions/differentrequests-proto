import ContractGeneration
import Foundation
import SwiftProtobufPluginLibrary

/// One `oneof`'s arms, ready to be written as a Swift extension.
///
/// The arm a message carries is the fact a reader branches on, and the compiler enforces that. What
/// it cannot give is the arm's *name*, which a log line or a diagnostic needs — and a switch
/// written by hand to supply it is a list of the schema's arms that has to be edited every time the
/// schema gains one. So it is emitted here, from the same descriptor the arms come from.
struct EmittedOneof {
  let typeName: String
  let arms: [EmittedOneofArm]

  /// The synthetic oneof protoc wraps a proto3 `optional` field in is not one of these: it is a
  /// compiler artifact rather than a choice the schema declares, and protoc's own generators skip
  /// it. `realOneofs` is the descriptor's own name for that distinction.
  init(oneof: OneofDescriptor, messageTypeName: String, namer: SwiftProtobufNamer) {
    typeName = "\(messageTypeName).\(namer.relativeName(oneof: oneof))"
    arms = oneof.fields.map { field in
      EmittedOneofArm(
        caseName: namer.messagePropertyNames(
          field: field,
          prefixed: "",
          includeHasAndClear: false
        ).name,
        fieldConstantName: field.name.lowerCamelCased
      )
    }
  }

  func swiftSource(messageTypeName: String) -> String {
    var out = """

      extension \(typeName) {
        /// Which arm this is, spelled as the schema spells the field it stands for.
        ///
        /// For a log line or a diagnostic. Never for a caller to branch on — the arm itself is
        /// what a caller branches on, and the compiler is what makes that exhaustive.
        public var fieldName: String {
          switch self {

      """
    for arm in arms {
      out += "    case .\(arm.caseName): return \(messageTypeName).Field.\(arm.fieldConstantName)\n"
    }
    out += """
          }
        }
      }

      """
    return out
  }
}
