import Foundation
import SwiftProtobuf
import SwiftProtobufPluginLibrary

/// Resolves an enum-valued option back to the Swift case protoc-gen-swift emits for it.
///
/// An option declared as an enum is a varint on the wire, and reading it as one is what lets a
/// generator take the value without linking the Swift that this package generates. The number on
/// its own says nothing, so it is resolved against the enum's own descriptor — reached through the
/// option that is typed by it, so nothing here names the enum.
///
/// Case names come from the same namer protoc-gen-swift uses, so the case this emits and the case
/// it declares are produced by one implementation.
public struct EnumCaseNames {
  private let enumDescriptor: EnumDescriptor
  private let namer: SwiftProtobufNamer

  /// The enum an option is typed by, found by the option's own field number.
  ///
  /// Searched in the file and everything it imports, because the option is declared where the
  /// enum is and neither is necessarily the file being generated for.
  public init(
    typing option: any AnyMessageExtension,
    reachableFrom file: FileDescriptor,
    namer: SwiftProtobufNamer
  ) throws {
    var searched = [file]
    searched.append(contentsOf: file.dependencies)

    for candidate in searched {
      for declared in candidate.extensions where declared.number == Int32(option.fieldNumber) {
        guard let typed = declared.enumType else {
          throw EnumCaseNameError.optionIsNotEnumTyped(fieldName: option.fieldName)
        }
        self.enumDescriptor = typed
        self.namer = namer
        return
      }
    }
    throw EnumCaseNameError.optionAbsent(fieldName: option.fieldName, protoFileName: file.name)
  }

  /// The Swift type protoc-gen-swift emits for this enum, for a generated property to be typed by.
  public var typeName: String {
    namer.fullName(enum: enumDescriptor)
  }

  public func caseName(forValue number: Int32) throws -> String {
    for value in enumDescriptor.values where value.number == number {
      return namer.relativeName(enumValue: value)
    }
    throw EnumCaseNameError.valueAbsent(enumName: enumDescriptor.name, number: number)
  }
}
