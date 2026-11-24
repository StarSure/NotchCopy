#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
VERSION="$(cat VERSION)"
APP="$ROOT/dist/NotchCopy.app"
MODE="${1:---native}"
if [[ "$MODE" != "--native" && "$MODE" != "--universal" ]]; then
  echo "Usage: Scripts/build.sh [--native|--universal]" >&2
  exit 2
fi
BINARIES=()
if [[ "$MODE" == "--universal" ]]; then ARCHS=(arm64 x86_64); else ARCHS=("$(uname -m)"); fi
for arch in "${ARCHS[@]}"; do
  swift build -c release --arch "$arch"
  BIN="$(swift build -c release --arch "$arch" --show-bin-path)/NotchCopy"
  # The Xcode-backed SwiftPM driver can reuse one Products/Release path.
  # Preserve each architecture before the next build overwrites that path.
  SAVED="$ROOT/.build/release-binaries/$arch/NotchCopy"
  mkdir -p "$(dirname "$SAVED")"
  cp "$BIN" "$SAVED"
  BINARIES+=("$SAVED")
done
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$ROOT/.build/icon.iconset"
if [[ "${#BINARIES[@]}" == "2" ]]; then
  lipo -create "${BINARIES[@]}" -output "$APP/Contents/MacOS/NotchCopy"
else
  cp "${BINARIES[0]}" "$APP/Contents/MacOS/NotchCopy"
fi
for arch in "${ARCHS[@]}"; do
  lipo "$APP/Contents/MacOS/NotchCopy" -verify_arch "$arch"
done
swift Scripts/make-icon.swift "$ROOT/.build/icon.iconset"
iconutil -c icns "$ROOT/.build/icon.iconset" -o "$APP/Contents/Resources/AppIcon.icns"
cp LICENSE NOTICE "$APP/Contents/Resources/"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>NotchCopy</string>
<key>CFBundleDisplayName</key><string>NotchCopy</string>
<key>CFBundleIdentifier</key><string>com.starsure.NotchCopy</string>
<key>CFBundleExecutable</key><string>NotchCopy</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>CFBundleShortVersionString</key><string>$VERSION</string>
<key>CFBundleVersion</key><string>$VERSION</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
<key>NSHumanReadableCopyright</key><string>Copyright 2026 StarSure. MIT. Adapted components Copyright 2026 akalikbergenov.</string>
</dict></plist>
PLIST
xattr -cr "$APP"
IDENTITY="${CODESIGN_IDENTITY:--}"
if [[ "$IDENTITY" == "-" ]]; then
  codesign --force --sign - "$APP"
else
  codesign --force --timestamp --options runtime --sign "$IDENTITY" "$APP"
fi
codesign --verify --strict "$APP"
if [[ "$MODE" == "--universal" ]]; then SUFFIX=universal; else SUFFIX="$(uname -m)"; fi
ZIP="NotchCopy-v${VERSION}-${SUFFIX}.zip"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ROOT/dist/$ZIP"
(cd dist && shasum -a 256 "$ZIP" > SHA256SUMS.txt)
echo "Built: dist/$ZIP"
