#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$ROOT/docs/screenshots"
BIN="$ROOT/.build/docs-capture/NotchCopyScreenshots"
mkdir -p "$OUT" "$(dirname "$BIN")"
SOURCES=()
for source in "$ROOT"/Sources/NotchCopy/*.swift; do
  case "$(basename "$source")" in main.swift|AppDelegate.swift) continue ;; esac
  SOURCES+=("$source")
done
xcrun swiftc -whole-module-optimization -Onone -swift-version 6 -target "$(uname -m)-apple-macos14.0" \
  "${SOURCES[@]}" "$ROOT/Scripts/Screenshots/main.swift" -o "$BIN"
CAPTURE_TMP="$(mktemp -d "${TMPDIR:-/tmp}/notchcopy-screenshots.XXXXXX")"
trap 'rm -rf "$CAPTURE_TMP"' EXIT
for scene in list search preview empty; do
  "$BIN" --demo "$scene" "$ROOT/Examples/snippets.example.json" "$CAPTURE_TMP/$scene.png"
  test -s "$CAPTURE_TMP/$scene.png"
  mv "$CAPTURE_TMP/$scene.png" "$OUT/$scene.png"
done
echo "Saved native demo panels to docs/screenshots/"
