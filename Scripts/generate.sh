#!/bin/sh
#
# Regenerates Sources/DifferentRequestsProtos/*.pb.swift from proto/*.proto.
#
# protoc-gen-swift is built from the swift-protobuf version pinned in
# Tools/protoc-plugin/Package.swift, never taken from PATH. An ambient plugin at
# a different version reformats every file, so the committed output would depend
# on whatever the developer happened to `brew install`. CI runs this script and
# fails if the working tree moves, which only holds if the plugin version is a
# property of the repo.
#
# The pin lives in the tools manifest, not the library manifest, so the
# swift-protobuf *runtime* a consumer links stays the consumer's choice.
#
# Every file here is compiled by protoc, including the service definitions —
# unlike backlog-proto, whose service file is read as text by its generators. The
# route options are real extensions, so a malformed path or a missing audience is
# a protoc error rather than something a downstream parser discovers later.

set -e

export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

if ! command -v protoc >/dev/null 2>&1; then
  echo "error: protoc not found on PATH. Install it with 'brew install protobuf'." >&2
  exit 1
fi

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
PACKAGE_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
PLUGIN_PKG="$PACKAGE_ROOT/Tools/protoc-plugin"
OUTPUT_PATH="$PACKAGE_ROOT/Sources/DifferentRequestsProtos"

swift build --package-path "$PLUGIN_PKG" --product protoc-gen-swift -c release
PLUGIN_BIN="$(swift build --package-path "$PLUGIN_PKG" --product protoc-gen-swift -c release --show-bin-path)/protoc-gen-swift"

mkdir -p "$OUTPUT_PATH"

protoc --proto_path="$PACKAGE_ROOT/proto" \
    --plugin=protoc-gen-swift="$PLUGIN_BIN" \
    --swift_opt=Visibility=Public \
    --swift_out="$OUTPUT_PATH" \
    "$PACKAGE_ROOT/proto/differentrequests_options.proto" \
    "$PACKAGE_ROOT/proto/differentrequests_domain.proto" \
    "$PACKAGE_ROOT/proto/differentrequests_sdk.proto"

# The endpoint table: one Swift case per rpc, carrying the path it is called at and
# the audience it declared. Generated so that no consumer — client or server — ever
# hand-writes a path string, which would be a copy of the service definition that
# nothing checks.
swift build --package-path "$PLUGIN_PKG" --product endpoint-gen -c release
ENDPOINT_GEN_BIN="$(swift build --package-path "$PLUGIN_PKG" --product endpoint-gen -c release --show-bin-path)/endpoint-gen"
"$ENDPOINT_GEN_BIN" "$PACKAGE_ROOT/proto/differentrequests_sdk.proto" "$OUTPUT_PATH"

# How an enum value is spelled in a URL, so the client that sends `?sort=top` and the
# server that matches on it read one fact rather than two copies of it.
swift build --package-path "$PLUGIN_PKG" --product tokens-gen -c release
TOKENS_GEN_BIN="$(swift build --package-path "$PLUGIN_PKG" --product tokens-gen -c release --show-bin-path)/tokens-gen"
"$TOKENS_GEN_BIN" "$PACKAGE_ROOT/proto/differentrequests_sdk.proto" "$OUTPUT_PATH"
"$TOKENS_GEN_BIN" "$PACKAGE_ROOT/proto/differentrequests_domain.proto" "$OUTPUT_PATH"

# Field names as the schema spells them, so a query key is never a literal typed twice.
swift build --package-path "$PLUGIN_PKG" --product fields-gen -c release
FIELDS_GEN_BIN="$(swift build --package-path "$PLUGIN_PKG" --product fields-gen -c release --show-bin-path)/fields-gen"
"$FIELDS_GEN_BIN" "$PACKAGE_ROOT/proto/differentrequests_sdk.proto" "$OUTPUT_PATH"

echo "Generated message types to $OUTPUT_PATH"
