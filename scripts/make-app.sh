#!/usr/bin/env bash
# Builds "AmbientBGMMenubar.app" into dist/, ready to run or to be put in a dmg.
#
# The app is a single Swift file compiled with swiftc (no Xcode project, no
# SwiftPM), so the .app around it is assembled here: a universal binary, an
# .icns made from resources/AppIcon.png, the two menu bar icons, and the
# Info.plist in packaging/ with the version filled in from the VERSION file.
#
#   scripts/make-app.sh                        # unsigned; for local use
#   scripts/make-app.sh --sign "Developer ID Application: ..."
#
# Nothing here talks to the network.
set -euo pipefail

cd "$(dirname "$0")/.."

IDENTITY=""
while [ $# -gt 0 ]; do
  case "$1" in
    --sign)
      IDENTITY="${2:-}"
      if [ -z "$IDENTITY" ]; then
        echo "Error: --sign needs an identity." >&2
        exit 1
      fi
      shift 2
      ;;
    *)
      echo "Usage: scripts/make-app.sh [--sign <identity>]" >&2
      exit 1
      ;;
  esac
done

VERSION=$(tr -d '[:space:]' < VERSION)
if [ -z "$VERSION" ]; then
  echo "Error: VERSION is empty." >&2
  exit 1
fi

# Must match LSMinimumSystemVersion in packaging/Info.plist.
MIN_MACOS=13.0
EXECUTABLE=AmbientBGMMenubar
APP="dist/AmbientBGMMenubar.app"

BUILD_DIR=$(mktemp -d)
trap 'rm -rf "$BUILD_DIR"' EXIT

# Both architectures, so that the one dmg runs on Intel and Apple Silicon alike.
echo "Building AmbientBGM Menubar $VERSION (universal) ..."
for arch in arm64 x86_64; do
  swiftc -O -target "${arch}-apple-macos${MIN_MACOS}" Sources/*.swift \
    -o "$BUILD_DIR/$EXECUTABLE-$arch"
done

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
lipo -create "$BUILD_DIR/$EXECUTABLE-arm64" "$BUILD_DIR/$EXECUTABLE-x86_64" \
  -output "$APP/Contents/MacOS/$EXECUTABLE"

# A single-architecture binary still runs on the machine that built it, so
# without this check the mistake would only show up on somebody else's Mac.
ARCHS=$(lipo -archs "$APP/Contents/MacOS/$EXECUTABLE")
if ! grep -q arm64 <<<"$ARCHS" || ! grep -q x86_64 <<<"$ARCHS"; then
  echo "Error: the binary is not universal: $ARCHS" >&2
  exit 1
fi

# Menu bar icons (white on transparent; main.swift marks them as templates and
# scales them to 18x18 pt). main.swift falls back to an emoji when they are
# missing, which is easy to miss in a release, so they are checked here.
cp resources/MenubarIcon.png resources/MenubarIconPlaying.png "$APP/Contents/Resources/"

# The .icns is generated rather than committed: AppIcon.png is the master, and a
# second copy of it in another format is a second thing to keep in step.
ICONSET="$BUILD_DIR/AppIcon.iconset"
mkdir -p "$ICONSET"
MASTER="resources/AppIcon.png"
sips -z 16 16     "$MASTER" --out "$ICONSET/icon_16x16.png"      >/dev/null
sips -z 32 32     "$MASTER" --out "$ICONSET/icon_16x16@2x.png"   >/dev/null
sips -z 32 32     "$MASTER" --out "$ICONSET/icon_32x32.png"      >/dev/null
sips -z 64 64     "$MASTER" --out "$ICONSET/icon_32x32@2x.png"   >/dev/null
sips -z 128 128   "$MASTER" --out "$ICONSET/icon_128x128.png"    >/dev/null
sips -z 256 256   "$MASTER" --out "$ICONSET/icon_128x128@2x.png" >/dev/null
sips -z 256 256   "$MASTER" --out "$ICONSET/icon_256x256.png"    >/dev/null
sips -z 512 512   "$MASTER" --out "$ICONSET/icon_256x256@2x.png" >/dev/null
sips -z 512 512   "$MASTER" --out "$ICONSET/icon_512x512.png"    >/dev/null
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"

sed "s/__VERSION__/${VERSION}/g" packaging/Info.plist > "$APP/Contents/Info.plist"
plutil -lint "$APP/Contents/Info.plist" >/dev/null
if grep -q "__VERSION__" "$APP/Contents/Info.plist"; then
  echo "Error: the version placeholder is still in the Info.plist." >&2
  exit 1
fi

if [ -n "$IDENTITY" ]; then
  # The only executable is Contents/MacOS; everything in Resources is data.
  # --options runtime (the hardened runtime) is what notarization requires;
  # --timestamp is what keeps the signature valid after the certificate expires.
  echo "Signing with: $IDENTITY"
  codesign --force --options runtime --timestamp --sign "$IDENTITY" "$APP"
  codesign --verify --deep --strict --verbose=2 "$APP"
fi

echo "Built $APP"
