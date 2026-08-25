import ContractGeneration
import Foundation
import SwiftProtobufPluginLibrary

/// One enum's URL spellings, ready to be written as a Swift extension.
struct EmittedTokenEnum {
  let typeName: String
  let spellings: [EmittedTokenValue]

  /// An enum where no value declares a spelling has nothing to emit, so it is not one of these.
  init?(enumDescriptor: EnumDescriptor, namer: SwiftProtobufNamer) {
    var found: [EmittedTokenValue] = []
    for value in enumDescriptor.values {
      guard let token = value.options.getExtensionValue(ext: contractURLTokenExtension) else {
        continue
      }
      found.append(
        EmittedTokenValue(caseName: namer.relativeName(enumValue: value), token: token)
      )
    }
    if found.isEmpty {
      return nil
    }
    typeName = namer.fullName(enum: enumDescriptor)
    spellings = found
  }

  var swiftSource: String {
    var out = """

      extension \(typeName) {
        /// How this value is spelled in a URL.
        ///
        /// Absent for a value with no declared spelling, which is what makes an unsendable value
        /// impossible to put in a query string rather than merely discouraged.
        public var urlToken: String? {
          switch self {

      """
    for spelling in spellings {
      out += "    case .\(spelling.caseName): return \"\(spelling.token)\"\n"
    }
    out += """
          default: return nil
          }
        }

        /// Reads a value back from its spelling. Nil for anything not in the contract, so an
        /// unrecognized token is rejected by the caller rather than silently becoming a default.
        public init?(urlToken: String) {
          switch urlToken {

      """
    for spelling in spellings {
      out += "    case \"\(spelling.token)\": self = .\(spelling.caseName)\n"
    }
    out += """
          default: return nil
          }
        }
      }

      """
    return out
  }
}
