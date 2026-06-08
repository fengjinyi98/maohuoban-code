#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "$ROOT"
cargo fmt --all --check
cargo test --workspace
cargo clippy --workspace --all-targets -- -D warnings
swift test --package-path maohuoban-diagnostics-sdk/swift
xcodebuild \
  -project "$ROOT/maohuoban/maohuoban.xcodeproj" \
  -scheme maohuoban \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -configuration Debug \
  build
