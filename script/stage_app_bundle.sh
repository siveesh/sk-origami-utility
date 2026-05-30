#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "usage: $0 <build-binary> <app-bundle>" >&2
  exit 2
fi

BUILD_BINARY="$1"
APP_BUNDLE="$2"
APP_NAME="SK Origami"
BUNDLE_ID="com.skorigami.app"
MIN_SYSTEM_VERSION="14.0"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_BINARY="$APP_MACOS/$APP_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_MACOS" "$APP_RESOURCES"
cp "$BUILD_BINARY" "$APP_BINARY"
chmod +x "$APP_BINARY"

if [[ -f "$ROOT_DIR/Resources/AppIcon.icns" ]]; then
  cp "$ROOT_DIR/Resources/AppIcon.icns" "$APP_RESOURCES/AppIcon.icns"
fi

if [[ -d "$ROOT_DIR/Resources/Tools" ]]; then
  cp -R "$ROOT_DIR/Resources/Tools" "$APP_RESOURCES/Tools"
fi

if [[ -d "$ROOT_DIR/Licenses" ]]; then
  cp -R "$ROOT_DIR/Licenses" "$APP_RESOURCES/Licenses"
fi

cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDocumentTypes</key>
  <array>
    <dict>
      <key>CFBundleTypeExtensions</key>
      <array>
        <string>zip</string>
        <string>7z</string>
        <string>rar</string>
        <string>tar</string>
        <string>gz</string>
        <string>tgz</string>
        <string>xz</string>
        <string>txz</string>
        <string>bz2</string>
        <string>tbz2</string>
        <string>jar</string>
        <string>apk</string>
        <string>drfx</string>
        <string>dat</string>
        <string>tnef</string>
      </array>
      <key>CFBundleTypeIconFile</key>
      <string>AppIcon</string>
      <key>CFBundleTypeName</key>
      <string>Archive</string>
      <key>CFBundleTypeRole</key>
      <string>Viewer</string>
      <key>LSHandlerRank</key>
      <string>Owner</string>
    </dict>
    <dict>
      <key>CFBundleTypeIconFile</key>
      <string>AppIcon</string>
      <key>CFBundleTypeName</key>
      <string>Folder</string>
      <key>CFBundleTypeRole</key>
      <string>Viewer</string>
      <key>LSHandlerRank</key>
      <string>Alternate</string>
      <key>LSItemContentTypes</key>
      <array>
        <string>public.folder</string>
      </array>
    </dict>
  </array>
  <key>NSServices</key>
  <array>
    <dict>
      <key>NSMenuItem</key>
      <dict>
        <key>default</key>
        <string>Create Disk Image with SK Origami</string>
      </dict>
      <key>NSMessage</key>
      <string>handleFolders</string>
      <key>NSPortName</key>
      <string>$APP_NAME</string>
      <key>NSSendTypes</key>
      <array>
        <string>NSFilenamesPboardType</string>
      </array>
    </dict>
  </array>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>LSApplicationCategoryType</key>
  <string>public.app-category.utilities</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
  <key>NSSupportsAutomaticGraphicsSwitching</key>
  <true/>
</dict>
</plist>
PLIST
