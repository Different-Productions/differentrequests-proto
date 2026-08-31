import ContractGeneration
import Foundation
import SwiftProtobuf
import SwiftProtobufPluginLibrary

/// One enum's prices, ready to be written as a Swift extension.
///
/// Only the values that declare `(monthly_cents)` appear. A value without one has no price and
/// answers `nil` rather than zero — the difference between "this step is free" and "nobody said what
/// this step costs", which is the difference between a bill and a bug.
struct EmittedPricedEnum {
  let typeName: String
  let prices: [EmittedPrice]

  /// An enum where no value declares a price has nothing to emit, so it is not one of these.
  init?(enumDescriptor: EnumDescriptor, namer: SwiftProtobufNamer) {
    var found: [EmittedPrice] = []
    for value in enumDescriptor.values {
      guard let cents = value.options.getExtensionValue(ext: DRExtensions_monthly_cents) else {
        continue
      }
      found.append(
        EmittedPrice(caseName: namer.relativeName(enumValue: value), monthlyCents: cents)
      )
    }
    if found.isEmpty {
      return nil
    }
    typeName = namer.fullName(enum: enumDescriptor)
    prices = found
  }

  var swiftSource: String {
    var out = """

      extension \(typeName) {

        /// What this step adds to a monthly bill, in cents.
        ///
        /// Cents rather than a decimal, because money in a floating-point number is money that
        /// eventually does not add up.
        ///
        /// Absent for a value that declares no price, which is what keeps an unpriced step out of a
        /// total rather than silently adding nothing to one.
        public var monthlyCents: Int? {
          switch self {

      """
    for price in prices {
      out += "    case .\(price.caseName): return \(price.monthlyCents)\n"
    }
    out += """
          default: return nil
          }
        }
      }

      """
    return out
  }
}
