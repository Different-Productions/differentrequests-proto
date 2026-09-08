import ContractGeneration
import Foundation
import SwiftProtobuf
import SwiftProtobufPluginLibrary

/// One enum's spellings, ready to be written as a Swift extension.
///
/// Three options declare a spelling and they mean different things. `(url_token)` is how a value is
/// written inside a URL this API already serves — a query parameter's value. `(token)` is the exact
/// string a value becomes when it leaves Swift for anything else: a verb on the wire, a header
/// name. `(label)` is the word a person is shown. An enum may declare any of them, and each becomes
/// its own property.
struct EmittedTokenEnum {
  let typeName: String
  let spellings: [EmittedSpelling]

  /// An enum where no value declares either spelling has nothing to emit, so it is not one of
  /// these.
  init?(enumDescriptor: EnumDescriptor, namer: SwiftProtobufNamer) {
    var found: [EmittedSpelling] = []

    let inURLs = Self.cases(
      of: enumDescriptor,
      spelledBy: DRExtensions_url_token,
      namer: namer
    )
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

    let onTheWire = Self.cases(
      of: enumDescriptor,
      spelledBy: DRExtensions_token,
      namer: namer
    )
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

    let shownToPeople = Self.cases(
      of: enumDescriptor,
      spelledBy: DRExtensions_label,
      namer: namer
    )
    if let unknown = Self.labelOfZeroValue(in: enumDescriptor) {
      found.append(
        EmittedSpelling(
          propertyName: "label",
          documentation: "What a person is shown for this value.",
          kind: .prose(whenUnrecognized: unknown),
          cases: shownToPeople
        )
      )
    }

    if found.isEmpty {
      return nil
    }
    typeName = namer.fullName(enum: enumDescriptor)
    spellings = found
  }

  /// The word the zero value is drawn as, which is what an enum declares to be a labeled one.
  ///
  /// It is also the word a value this build has never heard of is drawn as: a status from a newer
  /// server is, to this build, exactly the unspecified one.
  private static func labelOfZeroValue(in enumDescriptor: EnumDescriptor) -> String? {
    for value in enumDescriptor.values where value.number == 0 {
      return value.options.getExtensionValue(ext: DRExtensions_label)
    }
    return nil
  }

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
