#!/usr/bin/env bash
# Regenerates PlatKit/Realtime/gtfs_realtime.pb.swift from Proto/gtfs-realtime.proto.
# Requires: brew install protobuf swift-protobuf
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/PlatKit/Realtime"
mkdir -p "$OUT"
protoc \
  --swift_out="$OUT" \
  --proto_path="$ROOT/Proto" \
  "$ROOT/Proto/gtfs-realtime.proto"
echo "→ wrote $OUT/gtfs_realtime.pb.swift"
echo "Add it to the PlatKit framework target in Xcode."
