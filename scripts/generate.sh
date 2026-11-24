#!/usr/bin/env bash
# Regenerates `Sources/Qdrant/Generated` from `Protos/`. Run it after replacing the proto files with those of another
# Qdrant version.
#
# It needs `protoc`, `protoc-gen-swift` and `protoc-gen-grpc-swift-2` on the PATH. All three can be built in this
# package: `swift build -c release --product protoc` (likewise for the other two). A `protoc` built that way does not
# know where Google's own proto files are; point `PROTO_INCLUDE` at the folder that holds
# `google/protobuf/timestamp.proto` (`.build/checkouts/swift-protobuf/Protos/Sources/SwiftProtobuf`). The README's
# "Updating to another Qdrant version" lists the full commands.

set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

# The proto files stay as Qdrant ships them. The prefix is added to a copy, and it names the Swift types
# `QdrantPointStruct` where the generator's default would be `Qdrant_PointStruct`.
mkdir -p .build/protos
for proto in Protos/*.proto; do
  sed 's/^package qdrant;$/package qdrant;\noption swift_prefix = "Qdrant";/' "$proto" > ".build/protos/$(basename "$proto")"
done

rm -rf Sources/Qdrant/Generated
mkdir -p Sources/Qdrant/Generated
protoc --proto_path=.build/protos ${PROTO_INCLUDE:+--proto_path="$PROTO_INCLUDE"} \
  --swift_out=Sources/Qdrant/Generated --swift_opt=Visibility=Public \
  --grpc-swift-2_out=Sources/Qdrant/Generated --grpc-swift-2_opt=Visibility=Public,Client=true,Server=false \
  .build/protos/*.proto
# Files without messages or without services come out empty.
find Sources/Qdrant/Generated -name '*.swift' -size -1k -delete
