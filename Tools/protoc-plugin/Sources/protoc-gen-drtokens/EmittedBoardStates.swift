import ContractGeneration
import Foundation
import SwiftProtobufPluginLibrary

/// The values of one enum that a board can show, and the question that answers.
///
/// A board is what a person scrolls, and not every state belongs on one: a duplicate has left the
/// board for the request it was folded into. Only the server knew that, so the SDK offered a filter
/// the server refused every time — its filter bar is built from the values that declare a
/// `url_token`, which is deliberate and is how a status added to the schema reaches the bar with no
/// edit at all.
///
/// Emitted from the option, so the side that refuses a filter and the side that offers one are
/// reading the same fact. Absent is false, which is the safer way round: a state left off is a
/// filter somebody asks for, and a state on by mistake is a filter that fails.
struct EmittedBoardStates {
  let typeName: String

  /// Every case that says a board shows it, in schema order.
  let shown: [String]

  /// Every case that does not, the zero value included, so the switch emitted below is total.
  let hidden: [String]

  /// An enum where no value declares this has nothing to say about boards, so it is not one of
  /// these.
  init?(enumDescriptor: EnumDescriptor, namer: SwiftProtobufNamer) {
    var onTheBoard: [String] = []
    var offIt: [String] = []
    var anyDeclared = false

    for value in enumDescriptor.values {
      let name = namer.relativeName(enumValue: value)
      let declared = value.options.getExtensionValue(ext: DRExtensions_shown_on_a_board)
      if declared == true {
        anyDeclared = true
        onTheBoard.append(name)
      } else {
        offIt.append(name)
      }
    }

    guard anyDeclared else {
      return nil
    }
    typeName = namer.fullName(enum: enumDescriptor)
    shown = onTheBoard
    hidden = offIt
  }

  var swiftSource: String {
    var out = """

      extension \(typeName) {
        /// Whether a board can show requests in this state.
        ///
        /// The one fact behind both halves: a server refuses a filter naming a state that is not
        /// shown, and a client offers exactly the states that are.
        public var isShownOnABoard: Bool {
          switch self {

      """
    for name in shown {
      out += "    case .\(name): return true\n"
    }
    for name in hidden {
      out += "    case .\(name): return false\n"
    }
    out += """
          case .UNRECOGNIZED: return false
          }
        }

        /// Every state a board shows, in the order the schema declares them.
        ///
        /// What a filter bar is built from, so a state added to the schema appears without an edit
        /// anywhere else.
        public static let shownOnABoard: [\(typeName)] = [

      """
    for name in shown {
      out += "    .\(name),\n"
    }
    out += """
        ]
      }

      """
    return out
  }
}
