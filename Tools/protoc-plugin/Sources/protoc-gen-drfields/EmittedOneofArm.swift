import Foundation

/// One arm of a `oneof`: the Swift case that carries it, and the constant naming the field it
/// stands for.
struct EmittedOneofArm {
  let caseName: String
  let fieldConstantName: String
}
