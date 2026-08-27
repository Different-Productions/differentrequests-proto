import ContractGeneration
import Foundation
import SwiftProtobufPluginLibrary

/// A message whose fields say which surface each one decides, and the question that answers.
///
/// The rpc names a surface with `(plan_gate)` and the flag names the same surface with `(gates)`,
/// so "does this tenant have it" is one question with one answer — emitted here from both halves.
/// Written by hand it was two switches, one in the server and one in the SDK, and they had already
/// drifted: the server's knew two surfaces and the SDK's knew three.
struct EmittedGates {
  let messageTypeName: String
  let surfaceTypeName: String
  let gatedFields: [EmittedGate]

  /// A message where no field names a surface gates nothing, so it is not one of these.
  init?(message: Descriptor, namer: SwiftProtobufNamer) throws {
    var found: [EmittedGate] = []
    var surfaces: EnumCaseNames?

    for field in message.fields {
      guard let surface = field.options.getExtensionValue(ext: DRExtensions_gates) else {
        continue
      }
      let resolved: EnumCaseNames
      if let already = surfaces {
        resolved = already
      } else {
        resolved = try EnumCaseNames(
          typing: DRExtensions_gates,
          reachableFrom: message.file,
          namer: namer
        )
        surfaces = resolved
      }
      found.append(
        EmittedGate(
          surfaceCaseName: try resolved.caseName(forValue: Int32(surface.rawValue)),
          propertyName: namer.messagePropertyNames(
            field: field,
            prefixed: "",
            includeHasAndClear: false
          ).name
        )
      )
    }

    guard let surfaces, found.isEmpty == false else {
      return nil
    }
    messageTypeName = namer.fullName(message: message)
    surfaceTypeName = surfaces.typeName
    gatedFields = found
  }

  var swiftSource: String {
    var out = """

      extension \(messageTypeName) {
        /// Whether this config includes a surface.
        ///
        /// Generated from the fields that name one, so the flag a surface is answered against is
        /// the flag the schema says answers for it — on every side that asks.
        ///
        /// An unspecified or unrecognized surface is not included. A tenant whose entitlement
        /// cannot be identified is served the tier that costs them nothing rather than handed a
        /// surface, which is the same reading an unknown plan gets.
        public func includes(_ surface: \(surfaceTypeName)) -> Bool {
          switch surface {

      """
    for gate in gatedFields {
      out += "    case .\(gate.surfaceCaseName): return \(gate.propertyName)\n"
    }
    out += """
          case .unspecified, .UNRECOGNIZED: return false
          }
        }
      }

      """
    return out
  }
}
