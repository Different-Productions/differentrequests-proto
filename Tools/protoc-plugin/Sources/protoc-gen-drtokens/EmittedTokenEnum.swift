import ContractGeneration
import Foundation
import SwiftProtobufPluginLibrary

/// One enum's spellings, ready to be written as a Swift extension.
///
/// Two options declare a spelling and they mean different things. `(url_token)` is how a value is
/// written inside a URL this API already serves — a query parameter's value. `(token)` is the exact
/// string a value becomes when it leaves Swift for anything else: a verb on the wire, a header
/// name. An enum may declare either, or both, and each becomes its own property.
struct EmittedTokenEnum {
  let typeName: String
  let spellings: [EmittedSpelling]

  /// An enum where no value declares either spelling has nothing to emit, so it is not one of
  /// these.
  init?(enumDescriptor: EnumDescriptor, namer: SwiftProtobufNamer) {
    var found: [EmittedSpelling] = []

    let inURLs = Self.cases(
      of: enumDescriptor,
      spelledBy: contractURLTokenExtension,
      namer: namer
    )
    if inURLs.isEmpty == false {
      found.append(
        EmittedSpelling(
          propertyName: "urlToken",
          documentation: "How this value is spelled in a URL.",
          readBackDocumentation: "Reads a value back from its spelling in a URL.",
          cases: inURLs
        )
      )
    }

    let onTheWire = Self.cases(
      of: enumDescriptor,
      spelledBy: contractTokenExtension,
      namer: namer
    )
    if onTheWire.isEmpty == false {
      found.append(
        EmittedSpelling(
          propertyName: "token",
          documentation: "The exact string this value becomes when it leaves Swift.",
          readBackDocumentation: "Reads a value back from the string it becomes.",
          cases: onTheWire
        )
      )
    }

    if found.isEmpty {
      return nil
    }
    typeName = namer.fullName(enum: enumDescriptor)
    spellings = found
  }

  private static func cases(
    of enumDescriptor: EnumDescriptor,
    spelledBy option: ContractStringOption,
    namer: SwiftProtobufNamer
  ) -> [EmittedTokenValue] {
    var found: [EmittedTokenValue] = []
    for value in enumDescriptor.values {
      guard let token = value.options.getExtensionValue(ext: option) else {
        continue
      }
      found.append(
        EmittedTokenValue(caseName: namer.relativeName(enumValue: value), token: token)
      )
    }
    return found
  }

  var swiftSource: String {
    var out = """

      extension \(typeName) {
      """
    for spelling in spellings {
      out += spelling.swiftSource
    }
    out += """
      }

      """
    return out
  }
}
