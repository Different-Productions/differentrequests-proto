#!/bin/sh
#
# Regenerates every generated file under Sources/DifferentRequestsProtos from proto/*.proto.
#
# Each generator is a protoc plugin, the same shape protoc-gen-swift is: protoc parses the schema
# once and hands each of them descriptors. None of them opens a .proto file. A generator that read
# the text would be a second implementation of a grammar protoc already implements, and wrong
# wherever the two disagree — a brace opened by a `oneof` closing a message, a `//` inside a string
# literal starting a comment, a declaration split across lines never seen at all.
#
# Every plugin is built from the swift-protobuf version pinned in Tools/protoc-plugin/Package.swift,
# never taken from PATH. An ambient protoc-gen-swift at a different version reformats every
# generated file, so the committed output would depend on whatever the developer happened to
# `brew install`. CI runs this script and fails if the working tree moves, which only holds if the
# plugin version is a property of the repo.
#
# The pin lives in the tools manifest, not the library manifest, so the swift-protobuf *runtime* a
# consumer links stays the consumer's choice.

set -e

export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

# CI sets PROTOC to a pinned download so the Homebrew protoc a runner happens to carry cannot win
# the PATH lookup above.
PROTOC="${PROTOC:-protoc}"

if ! command -v "$PROTOC" >/dev/null 2>&1; then
  echo "error: protoc not found at '$PROTOC'. Install it with 'brew install protobuf', or set PROTOC to a pinned binary." >&2
  exit 1
fi

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
PACKAGE_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
PLUGIN_PKG="$PACKAGE_ROOT/Tools/protoc-plugin"
PROTO_PATH="$PACKAGE_ROOT/proto"
OUTPUT_PATH="$PACKAGE_ROOT/Sources/DifferentRequestsProtos"

# differentrequests_options.proto extends google.protobuf.MethodOptions and EnumValueOptions, so
# descriptor.proto has to resolve; it ships in the include directory beside protoc's own bin.
PROTOC_INCLUDE="$(dirname "$(command -v "$PROTOC")")/../include"
if [ ! -f "$PROTOC_INCLUDE/google/protobuf/descriptor.proto" ]; then
  echo "error: '$PROTOC' has no include directory at '$PROTOC_INCLUDE'. google/protobuf/descriptor.proto must resolve for the custom options to parse." >&2
  exit 1
fi

plugin_binary() {
  swift build --package-path "$PLUGIN_PKG" --product "$1" -c release >&2
  echo "$(swift build --package-path "$PLUGIN_PKG" --product "$1" -c release --show-bin-path)/$1"
}

SWIFT_BIN=$(plugin_binary protoc-gen-swift)
ENDPOINTS_BIN=$(plugin_binary protoc-gen-drendpoints)
TOKENS_BIN=$(plugin_binary protoc-gen-drtokens)
FIELDS_BIN=$(plugin_binary protoc-gen-drfields)
VOCAB_BIN=$(plugin_binary protoc-gen-drvocab)

mkdir -p "$OUTPUT_PATH"

# protoc writes files and never removes them, so an enum dropped from the vocabulary would leave its
# Swift behind. The directory is generated in full on every run, so it is emptied first.
rm -rf "$OUTPUT_PATH/Vocabulary"

# The message types. The vocabulary is deliberately absent: a proto enum value is an integer, and
# what the vocabulary is *for* is the string it spells, which protoc-gen-swift cannot emit.
"$PROTOC" --proto_path="$PROTO_PATH" \
    --proto_path="$PROTOC_INCLUDE" \
    --plugin=protoc-gen-swift="$SWIFT_BIN" \
    --swift_opt=Visibility=Public \
    --swift_out="$OUTPUT_PATH" \
    "$PROTO_PATH/differentrequests_options.proto" \
    "$PROTO_PATH/differentrequests_domain.proto" \
    "$PROTO_PATH/differentrequests_sdk.proto"

# The endpoint table: one Swift case per rpc, carrying the path it is called at and the audience it
# declared. Generated so that no consumer — client or server — ever hand-writes a path string, which
# would be a copy of the service definition that nothing checks.
#
# Field names as the schema spells them, so a query key is never a literal typed twice.
"$PROTOC" --proto_path="$PROTO_PATH" \
    --proto_path="$PROTOC_INCLUDE" \
    --plugin=protoc-gen-drendpoints="$ENDPOINTS_BIN" \
    --plugin=protoc-gen-drfields="$FIELDS_BIN" \
    --drendpoints_out="$OUTPUT_PATH" \
    --drfields_out="$OUTPUT_PATH" \
    "$PROTO_PATH/differentrequests_sdk.proto"

# How an enum value is spelled in a URL, so the client that sends `?sort=top` and the server that
# matches on it read one fact rather than two copies of it.
"$PROTOC" --proto_path="$PROTO_PATH" \
    --proto_path="$PROTOC_INCLUDE" \
    --plugin=protoc-gen-drtokens="$TOKENS_BIN" \
    --drtokens_out="$OUTPUT_PATH" \
    "$PROTO_PATH/differentrequests_sdk.proto" \
    "$PROTO_PATH/differentrequests_domain.proto"

# The vocabulary: values whose contract *is* their spelling — an HTTP header, an authorization
# scheme, a media type. Every one of them was a literal in the server and the SDK both until it was
# declared in the proto.
"$PROTOC" --proto_path="$PROTO_PATH" \
    --proto_path="$PROTOC_INCLUDE" \
    --plugin=protoc-gen-drvocab="$VOCAB_BIN" \
    --drvocab_out="$OUTPUT_PATH" \
    "$PROTO_PATH/differentrequests_vocabulary.proto"

echo "Generated to $OUTPUT_PATH"
