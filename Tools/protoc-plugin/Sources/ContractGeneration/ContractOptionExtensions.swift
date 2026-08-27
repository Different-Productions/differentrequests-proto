import SwiftProtobuf
import SwiftProtobufPluginLibrary

/// Every custom option the contract declares, for a generator's `customOptionExtensions`.
///
/// Read from `differentrequests_options.pb.swift`, generated into this module from the same
/// `.proto` the contract package generates its own copy from. Nothing here spells a field number:
/// a number typed beside the generated symbol already holding it is a number that can disagree
/// with the schema, and the way it disagrees is every option reading as absent — a vocabulary that
/// declares nothing, rather than an error.
public let contractOptionExtensions: [any AnyMessageExtension] = [
  DRExtensions_url_token,
  DRExtensions_token,
  DRExtensions_route_method,
  DRExtensions_route_path,
  DRExtensions_route_audience,
  DRExtensions_plan_gate,
  DRExtensions_gates
]
