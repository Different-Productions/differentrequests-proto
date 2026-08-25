import Foundation
import SwiftProtobufPluginLibrary

/// Resolves an enum-valued option back to the Swift case protoc-gen-swift emits for it.
///
/// An option declared as an enum is a varint on the wire, and reading it as one is what lets a
/// generator take the value without linking the Swift for the file that declares the enum. The
/// number on its own says nothing, so it is resolved here against the enum's own descriptor — and
/// through the same namer protoc-gen-swift uses, so the case this emits and the case it declares
/// are produced by one implementation.
public struct EnumCaseNames {
  private let enums: [EnumDescriptor]
  private let namer: SwiftProtobufNamer

  /// The enums a file can name: the ones it declares and the ones it imports.
  public init(reachableFrom file: FileDescriptor, namer: SwiftProtobufNamer) {
    var reachable = file.enums
    for dependency in file.dependencies {
      reachable.append(contentsOf: dependency.enums)
    }
    enums = reachable
    self.namer = namer
  }

  public func caseName(forValue number: Int32, ofEnumNamed enumName: String) throws -> String {
    for declared in enums where declared.name == enumName {
      for value in declared.values where value.number == number {
        return namer.relativeName(enumValue: value)
      }
      throw EnumCaseNameError.valueAbsent(enumName: enumName, number: number)
    }
    throw EnumCaseNameError.enumAbsent(enumName: enumName)
  }

  /// The Swift type protoc-gen-swift emits for this enum, for a generated property to be typed by.
  public func typeName(ofEnumNamed enumName: String) throws -> String {
    for declared in enums where declared.name == enumName {
      return namer.fullName(enum: declared)
    }
    throw EnumCaseNameError.enumAbsent(enumName: enumName)
  }
}
