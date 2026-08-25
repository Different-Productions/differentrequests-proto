import Foundation

let usage = """
usage: vocab-gen <descriptor-set> <output-directory> <proto-file>...

  <descriptor-set>   a FileDescriptorSet from
                     protoc --include_imports --include_source_info
                            --descriptor_set_out
  <output-directory> where the vocabulary's Swift is written
  <proto-file>       the file name protoc recorded, relative to --proto_path
"""

let arguments = CommandLine.arguments
if arguments.count < 4 {
  FileHandle.standardError.write(Data("\(usage)\n".utf8))
  exit(2)
}

let generator = VocabularyGenerator(
  descriptorSetPath: arguments[1],
  outputDirectory: arguments[2],
  protoFileNames: Array(arguments[3...])
)

do {
  let report = try generator.generate()
  for line in report {
    print(line)
  }
} catch let error as VocabularyError {
  FileHandle.standardError.write(Data("vocab-gen error: \(error.message)\n".utf8))
  exit(1)
} catch {
  FileHandle.standardError.write(Data("vocab-gen error: \(error)\n".utf8))
  exit(1)
}
