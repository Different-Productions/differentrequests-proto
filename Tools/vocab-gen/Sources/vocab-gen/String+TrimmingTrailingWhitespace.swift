import Foundation

extension String {
  /// Leading whitespace is a doc comment's indentation and is kept.
  var trimmingTrailingWhitespace: String {
    var trimmed = Substring(self)
    while let last = trimmed.last, last.isWhitespace {
      trimmed = trimmed.dropLast()
    }
    return String(trimmed)
  }
}
