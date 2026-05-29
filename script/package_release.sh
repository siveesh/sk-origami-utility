#!/usr/bin/env bash
set -euo pipefail

APP_NAME="SK Origami"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
RELEASE_DIR="$DIST_DIR/releases"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
VERSION="${1:-0.1.0}"

cd "$ROOT_DIR"
"$ROOT_DIR/script/verify_bundled_tools.sh"
swift build -c release
BUILD_BINARY="$(swift build -c release --show-bin-path)/$APP_NAME"

"$ROOT_DIR/script/stage_app_bundle.sh" "$BUILD_BINARY" "$APP_BUNDLE"
"$ROOT_DIR/script/verify_app_bundle.sh"

find "$APP_BUNDLE/Contents/Resources/Tools" -type f \( -perm -111 -o -name "*.so" \) -print0 | while IFS= read -r -d '' item; do
  if file "$item" | grep -q "Mach-O"; then
    /usr/bin/codesign --force --sign - --timestamp=none "$item"
  fi
done

/usr/bin/codesign --force --deep --sign - --timestamp=none "$APP_BUNDLE"
/usr/bin/codesign --verify --deep --strict "$APP_BUNDLE"

rm -rf "$RELEASE_DIR"
mkdir -p "$RELEASE_DIR"

/usr/bin/ditto -c -k --keepParent "$APP_BUNDLE" "$RELEASE_DIR/SK-Origami-$VERSION-macOS-arm64.zip"

rm -f "$RELEASE_DIR/SK-Origami-$VERSION-macOS-arm64.dmg"
/usr/bin/hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$APP_BUNDLE" \
  -ov \
  -format UDZO \
  "$RELEASE_DIR/SK-Origami-$VERSION-macOS-arm64.dmg"

rm -f "$RELEASE_DIR/SK-Origami-$VERSION-macOS-arm64.pkg"
/usr/bin/productbuild \
  --component "$APP_BUNDLE" /Applications \
  "$RELEASE_DIR/SK-Origami-$VERSION-macOS-arm64.pkg"

(
  cd "$RELEASE_DIR"
  shasum -a 256 SK-Origami-"$VERSION"-macOS-arm64.zip \
    SK-Origami-"$VERSION"-macOS-arm64.dmg \
    SK-Origami-"$VERSION"-macOS-arm64.pkg > SHA256SUMS.txt
)
echo "Release artifacts written to $RELEASE_DIR"
