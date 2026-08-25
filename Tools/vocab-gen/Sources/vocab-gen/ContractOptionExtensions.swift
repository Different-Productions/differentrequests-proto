import SwiftProtobuf

/// The extension field number is differentrequests_options.proto's; a change there
/// without a change here reads every option as absent.
let contractTokenExtension = SwiftProtobuf.MessageExtension<
  SwiftProtobuf.OptionalExtensionField<SwiftProtobuf.ProtobufString>,
  SwiftProtobuf.Google_Protobuf_EnumValueOptions
>(_protobuf_fieldNumber: 51242, fieldName: "differentrequests.v1.token")

/// Descriptors parsed without this map carry the option as an unknown field, which
/// reads as a vocabulary that declares nothing.
let contractExtensions: SwiftProtobuf.SimpleExtensionMap = [
  contractTokenExtension
]
