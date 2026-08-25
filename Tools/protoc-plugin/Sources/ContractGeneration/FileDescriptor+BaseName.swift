import Foundation
import SwiftProtobufPluginLibrary

extension FileDescriptor {
  /// The file name protoc recorded, without its directory or its `.proto` extension. What the
  /// generated file is named after.
  public var baseName: String {
    let leaf = (name as NSString).lastPathComponent
    return (leaf as NSString).deletingPathExtension
  }
}
