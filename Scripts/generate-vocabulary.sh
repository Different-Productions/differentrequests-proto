#!/bin/sh
#
# Regenerates the vocabulary's Swift from proto/differentrequests_vocabulary.proto.
#
# protoc cannot emit these: a proto enum value is an integer, and the whole point of
# the vocabulary is the string it spells. So protoc renders a descriptor set and
# vocab-gen reads the custom option off it.
#
# vocab-gen is built from the swift-protobuf version pinned in
# Tools/vocab-gen/Package.swift, which matches Tools/protoc-plugin. Both readers
# resolve case names through the same SwiftProtobufNamer, so a vocabulary case and a
# .pb.swift case are named by one implementation.
#
# Output is a pure function of the .proto: run it twice, get the same bytes. The
# generator deletes any Swift file left in the output directory that the vocabulary
# no longer declares.
#
# Usage:
#   Scripts/generate-vocabulary.sh              write into the repository
#   Scripts/generate-vocabulary.sh <directory>  write the same files under <directory>

set -e

export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

# CI sets PROTOC to a pinned download so the Homebrew protoc a runner happens to
# carry cannot win the PATH lookup above.
PROTOC="${PROTOC:-protoc}"

if ! command -v "$PROTOC" >/dev/null 2>&1; then
  echo "error: protoc not found at '$PROTOC'. Install it with 'brew install protobuf', or set PROTOC to a pinned binary." >&2
  exit 1
fi

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
PACKAGE_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
OUTPUT_DIR="${1:-$PACKAGE_ROOT/Sources/DifferentRequestsProtos/Vocabulary}"
GENERATOR_PKG="$PACKAGE_ROOT/Tools/vocab-gen"

swift build --package-path "$GENERATOR_PKG" --product vocab-gen -c release
GENERATOR_BIN="$(swift build --package-path "$GENERATOR_PKG" --product vocab-gen -c release --show-bin-path)/vocab-gen"

# An explicit `XXXXXX` template rather than `mktemp -t <prefix>`: the `-t` form is
# BSD's, and GNU mktemp refuses a template with too few X's — which is every run of
# this on the Linux container CI uses.
DESCRIPTOR_SET=$(mktemp "${TMPDIR:-/tmp}/differentrequests_vocabulary.XXXXXX")
trap 'rm -f "$DESCRIPTOR_SET"' EXIT

# differentrequests_options.proto extends google.protobuf.EnumValueOptions, so
# descriptor.proto has to resolve; it ships in the include directory beside protoc's
# own bin.
PROTOC_INCLUDE="$(dirname "$(command -v "$PROTOC")")/../include"
if [ ! -f "$PROTOC_INCLUDE/google/protobuf/descriptor.proto" ]; then
  echo "error: '$PROTOC' has no include directory at '$PROTOC_INCLUDE'. google/protobuf/descriptor.proto must resolve for the vocabulary options to parse." >&2
  exit 1
fi

# --include_imports carries differentrequests_options.proto in so the custom option
# resolves; --include_source_info carries the .proto's comments through to the
# generated doc comments.
"$PROTOC" --proto_path="$PACKAGE_ROOT/proto" \
    --proto_path="$PROTOC_INCLUDE" \
    --include_imports \
    --include_source_info \
    --descriptor_set_out="$DESCRIPTOR_SET" \
    "$PACKAGE_ROOT/proto/differentrequests_vocabulary.proto"

"$GENERATOR_BIN" "$DESCRIPTOR_SET" "$OUTPUT_DIR" differentrequests_vocabulary.proto
