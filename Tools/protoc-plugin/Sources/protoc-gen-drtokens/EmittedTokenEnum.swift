import ContractGeneration
import Foundation
import SwiftProtobuf
import SwiftProtobufPluginLibrary

/// One enum's spellings, ready to be written as a Swift extension.
///
/// Five options declare a spelling and they mean different things. `(url_token)` is how a value is
/// written inside a URL this API already serves — a query parameter's value. `(token)` is the exact
/// string a value becomes when it leaves Swift for anything else: a verb on the wire, a header
/// name. `(label)` is the word a person is shown, `(pitch)` the sentence on what it does, and
/// `(picture)` the outline drawn beside it. An enum may declare any of them, and each becomes its
/// own property.
struct EmittedTokenEnum {
  let typeName: String
  let spellings: [EmittedSpelling]

  /// An enum where no value declares either spelling has nothing to emit, so it is not one of
  /// these.
  init?(enumDescriptor: EnumDescriptor, namer: SwiftProtobufNamer) {
    var found: [EmittedSpelling] = []

    let inURLs = Self.cases(of: enumDescriptor, spelledBy: DRExtensions_url_token, namer: namer)
    if inURLs.isEmpty == false {
      found.append(
        EmittedSpelling(
          propertyName: "urlToken",
          documentation: "How this value is spelled in a URL.",
          kind: .identifier(readBackDocumentation: "Reads a value back from its spelling in a URL."),
          cases: inURLs
        )
      )
    }

    let onTheWire = Self.cases(of: enumDescriptor, spelledBy: DRExtensions_token, namer: namer)
    if onTheWire.isEmpty == false {
      found.append(
        EmittedSpelling(
          propertyName: "token",
          documentation: "The exact string this value becomes when it leaves Swift.",
          kind: .identifier(readBackDocumentation: "Reads a value back from the string it becomes."),
          cases: onTheWire
        )
      )
    }

    let prose: [(option: ProseOption, propertyName: String, documentation: String)] = [
      (DRExtensions_label, "label", "What a person is shown for this value."),
      (DRExtensions_pitch, "pitch", "One sentence on what this value does for the developer who has it."),
      (DRExtensions_picture, "picture", "The outline drawn beside this value: one stroked SVG path on a 24-point grid.")
    ]
    // The zero value's spelling is what makes an enum one that has the option, and it is also what
    // a value this build has never heard of is drawn as.
    for (option, propertyName, documentation) in prose {
      for zeroValue in enumDescriptor.values where zeroValue.number == 0 {
        if let unknown = zeroValue.options.getExtensionValue(ext: option) {
          found.append(
            EmittedSpelling(
              propertyName: propertyName,
              documentation: documentation,
              kind: .prose(whenUnrecognized: unknown),
              cases: Self.cases(of: enumDescriptor, spelledBy: option, namer: namer)
            )
          )
        }
      }
    }

    if found.isEmpty {
      return nil
    }
    typeName = namer.fullName(enum: enumDescriptor)
    spellings = found
  }

  private typealias ProseOption = MessageExtension<
    OptionalExtensionField<ProtobufString>,
    Google_Protobuf_EnumValueOptions
  >

  private static func cases(
    of enumDescriptor: EnumDescriptor,
    spelledBy option: MessageExtension<
      OptionalExtensionField<ProtobufString>,
      Google_Protobuf_EnumValueOptions
    >,
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
