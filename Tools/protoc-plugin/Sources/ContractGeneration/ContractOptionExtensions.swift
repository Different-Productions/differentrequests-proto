import SwiftProtobuf
import SwiftProtobufPluginLibrary

/// The custom options differentrequests_options.proto declares, handed to protoc's plugin library
/// so a generator reads a value rather than an unknown field.
///
/// The field numbers are the ones the schema declares. A change there without a change here reads
/// every option as absent — a vocabulary that declares nothing, rather than an error — which is why
/// each generator fails loudly on a value it expected an option for.

/// A string option on an enum value. Both spellings the contract declares have this shape, so a
/// generator can take either as an argument rather than being written twice.
public typealias ContractStringOption = SwiftProtobuf.MessageExtension<
  SwiftProtobuf.OptionalExtensionField<SwiftProtobuf.ProtobufString>,
  SwiftProtobuf.Google_Protobuf_EnumValueOptions
>

public let contractURLTokenExtension = SwiftProtobuf.MessageExtension<
  SwiftProtobuf.OptionalExtensionField<SwiftProtobuf.ProtobufString>,
  SwiftProtobuf.Google_Protobuf_EnumValueOptions
>(_protobuf_fieldNumber: 51241, fieldName: "differentrequests.v1.url_token")

public let contractTokenExtension = SwiftProtobuf.MessageExtension<
  SwiftProtobuf.OptionalExtensionField<SwiftProtobuf.ProtobufString>,
  SwiftProtobuf.Google_Protobuf_EnumValueOptions
>(_protobuf_fieldNumber: 51242, fieldName: "differentrequests.v1.token")

/// Declared as an enum in the schema and read here as the varint it is on the wire. The number is
/// resolved back to a case name through the enum's own descriptor, which is what lets this
/// generator read the option without linking the Swift that this package generates.
public let contractRouteMethodExtension = SwiftProtobuf.MessageExtension<
  SwiftProtobuf.OptionalExtensionField<SwiftProtobuf.ProtobufInt32>,
  SwiftProtobuf.Google_Protobuf_MethodOptions
>(_protobuf_fieldNumber: 51243, fieldName: "differentrequests.v1.route_method")

public let contractRoutePathExtension = SwiftProtobuf.MessageExtension<
  SwiftProtobuf.OptionalExtensionField<SwiftProtobuf.ProtobufString>,
  SwiftProtobuf.Google_Protobuf_MethodOptions
>(_protobuf_fieldNumber: 51244, fieldName: "differentrequests.v1.route_path")

public let contractRouteAudienceExtension = SwiftProtobuf.MessageExtension<
  SwiftProtobuf.OptionalExtensionField<SwiftProtobuf.ProtobufInt32>,
  SwiftProtobuf.Google_Protobuf_MethodOptions
>(_protobuf_fieldNumber: 51245, fieldName: "differentrequests.v1.route_audience")

/// Absent on an rpc every plan includes, which is why nothing here treats a missing value as an
/// error the way an absent route is one.
public let contractPlanGateExtension = SwiftProtobuf.MessageExtension<
  SwiftProtobuf.OptionalExtensionField<SwiftProtobuf.ProtobufInt32>,
  SwiftProtobuf.Google_Protobuf_MethodOptions
>(_protobuf_fieldNumber: 51246, fieldName: "differentrequests.v1.plan_gate")

/// Every custom option in the contract, for a generator's `customOptionExtensions`.
public let contractOptionExtensions: [any AnyMessageExtension] = [
  contractURLTokenExtension,
  contractTokenExtension,
  contractRouteMethodExtension,
  contractRoutePathExtension,
  contractRouteAudienceExtension,
  contractPlanGateExtension
]
