#!/usr/bin/env bash
# Regenerates NextStopKit/Realtime/gtfs_realtime.pb.swift from Proto/gtfs-realtime.proto.
# Requires: brew install protobuf swift-protobuf
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/NextStopKit/Realtime"
mkdir -p "$OUT"
protoc \
  --swift_out="$OUT" \
  --proto_path="$ROOT/Proto" \
  "$ROOT/Proto/gtfs-realtime.proto"
echo "→ wrote $OUT/gtfs_realtime.pb.swift"
echo "Add it to the NextStopKit framework target in Xcode."
