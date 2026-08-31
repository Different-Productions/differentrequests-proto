import Foundation

/// One enum value's price: the Swift case that carries it, and what it costs per month in cents.
struct EmittedPrice {
  let caseName: String
  let monthlyCents: Int32
}
