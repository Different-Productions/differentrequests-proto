import Foundation
import SwiftProtobuf
import SwiftProtobufPluginLibrary

/// Reads a protoc-produced `FileDescriptorSet` and emits one Swift file per
/// vocabulary enum.
///
/// One output directory rather than a routed set, because this package emits one
/// module. LiminalWallet's vocab-gen routes by `(audience)` because three modules in
/// one repository share its vocabulary; here the server and the SDK both link
/// `DifferentRequestsProtos`, so an audience would be an option with one value and
/// nothing to decide.
///
/// Output is a pure function of the descriptor set: enums in declaration order,
/// values in declaration order, no timestamps and no host paths.
struct VocabularyGenerator {
  let descriptorSetPath: String
  let outputDirectory: String
  let protoFileNames: [String]

  func generate() throws -> [String] {
    let descriptorSet = try loadDescriptorSet()
    let namer = SwiftProtobufNamer()
    var emitted: [EmittedEnum] = []
    for protoFileName in protoFileNames {
      let file = try fileDescriptor(named: protoFileName, in: descriptorSet)
      if let message = file.messages.first {
        throw VocabularyError.messageDeclared(
          protoFileName: protoFileName,
          messageName: message.name
        )
      }
      for enumDescriptor in file.enums {
        emitted.append(
          try emittedEnum(for: enumDescriptor, protoFileName: protoFileName, namer: namer)
        )
      }
    }
    if emitted.isEmpty {
      throw VocabularyError.nothingEmitted(protoFileNames: protoFileNames)
    }
    return try write(emitted)
  }

  private func loadDescriptorSet() throws -> DescriptorSet {
    let data: Data
    do {
      data = try Data(contentsOf: URL(fileURLWithPath: descriptorSetPath))
    } catch {
      throw VocabularyError.descriptorUnreadable(
        path: descriptorSetPath,
        reason: "\(error)"
      )
    }
    let proto: Google_Protobuf_FileDescriptorSet
    do {
      proto = try Google_Protobuf_FileDescriptorSet(
        serializedBytes: [UInt8](data),
        extensions: contractExtensions
      )
    } catch {
      throw VocabularyError.descriptorUndecodable(
        path: descriptorSetPath,
        reason: "\(error)"
      )
    }
    return DescriptorSet(proto: proto)
  }

  private func fileDescriptor(
    named protoFileName: String,
    in descriptorSet: DescriptorSet
  ) throws -> FileDescriptor {
    for file in descriptorSet.files where file.name == protoFileName {
      return file
    }
    throw VocabularyError.protoFileAbsent(
      protoFileName: protoFileName,
      descriptorSetPath: descriptorSetPath
    )
  }

  private func emittedEnum(
    for enumDescriptor: EnumDescriptor,
    protoFileName: String,
    namer: SwiftProtobufNamer
  ) throws -> EmittedEnum {
    let name = namer.relativeName(enum: enumDescriptor)

    var cases: [EmittedCase] = []
    var valueNameForToken: [String: String] = [:]
    var valueNameForCaseName: [String: String] = [:]
    for value in enumDescriptor.values {
      guard let token = value.options.getExtensionValue(ext: contractTokenExtension) else {
        throw VocabularyError.tokenAbsent(enumName: name, valueName: value.name)
      }
      if let owner = valueNameForToken[token] {
        throw VocabularyError.tokenDuplicated(
          enumName: name,
          token: token,
          first: owner,
          second: value.name
        )
      }
      valueNameForToken[token] = value.name
      let caseName = namer.relativeName(enumValue: value)
      if let owner = valueNameForCaseName[caseName] {
        throw VocabularyError.caseNameDuplicated(
          enumName: name,
          caseName: "\(caseName) (from \(owner) and \(value.name))"
        )
      }
      valueNameForCaseName[caseName] = value.name
      cases.append(
        EmittedCase(
          name: caseName,
          token: token,
          documentation: documentation(for: value)
        )
      )
    }

    return EmittedEnum(
      name: name,
      documentation: documentation(for: enumDescriptor),
      cases: cases,
      protoFileName: protoFileName
    )
  }

  private func documentation(for source: any ProvidesSourceCodeLocation) -> [String] {
    let comment = source.protoSourceComments(commentPrefix: "///", leadingDetachedPrefix: nil)
    var lines: [String] = []
    for line in comment.split(separator: "\n", omittingEmptySubsequences: false) {
      let trimmed = String(line).trimmingTrailingWhitespace
      if trimmed.isEmpty {
        continue
      }
      lines.append(trimmed)
    }
    return lines
  }

  private func write(_ emitted: [EmittedEnum]) throws -> [String] {
    let fileManager = FileManager.default
    var report: [String] = []
    var emittedNames: Set<String> = []

    do {
      try fileManager.createDirectory(
        atPath: outputDirectory,
        withIntermediateDirectories: true
      )
    } catch {
      throw VocabularyError.directoryUncreatable(path: outputDirectory, reason: "\(error)")
    }

    for emittedEnum in emitted {
      let path = "\(outputDirectory)/\(emittedEnum.fileName)"
      let contents = Data(emittedEnum.swiftSource.utf8)
      if fileManager.contents(atPath: path) != contents {
        do {
          try contents.write(to: URL(fileURLWithPath: path), options: .atomic)
        } catch {
          throw VocabularyError.fileUnwritable(path: path, reason: "\(error)")
        }
      }
      emittedNames.formUnion([emittedEnum.fileName])
      report.append("\(path)  \(emittedEnum.cases.count) tokens")
    }

    report.append(contentsOf: try sweep(keeping: emittedNames))
    return report
  }

  /// The generated directory holds generated files only, so a file this run did not
  /// emit describes an enum the proto no longer declares.
  private func sweep(keeping emittedNames: Set<String>) throws -> [String] {
    let fileManager = FileManager.default
    let present: [String]
    do {
      present = try fileManager.contentsOfDirectory(atPath: outputDirectory)
    } catch {
      throw VocabularyError.directoryUncreatable(path: outputDirectory, reason: "\(error)")
    }
    var report: [String] = []
    for name in present.sorted() where name.hasSuffix(".swift") && !emittedNames.contains(name) {
      let path = "\(outputDirectory)/\(name)"
      do {
        try fileManager.removeItem(atPath: path)
      } catch {
        throw VocabularyError.fileUnwritable(path: path, reason: "\(error)")
      }
      report.append("removed  \(path)  (no longer in the vocabulary)")
    }
    return report
  }
}
