#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_BUNDLE="$ROOT_DIR/dist/SK Origami.app"
TOOLS_DIR="$APP_BUNDLE/Contents/Resources/Tools/darwin-arm64"

required_tools=(7zz 7z.so unar lsar tnef)

if [[ ! -d "$APP_BUNDLE" ]]; then
  echo "Missing staged app bundle: $APP_BUNDLE"
  exit 1
fi

for tool in "${required_tools[@]}"; do
  path="$TOOLS_DIR/$tool"
  if [[ ! -f "$path" ]]; then
    echo "Missing bundled helper in app bundle: $path"
    exit 1
  fi

  if [[ "$tool" != "7z.so" && ! -x "$path" ]]; then
    echo "Bundled helper is not executable: $path"
    exit 1
  fi

  resolved="$(realpath "$path")"
  case "$resolved" in
    "$APP_BUNDLE"/Contents/Resources/Tools/darwin-arm64/*)
      ;;
    *)
      echo "Bundled helper resolves outside the app bundle: $path"
      echo "$resolved"
      exit 1
      ;;
  esac
done

if find "$APP_BUNDLE/Contents" -type l | grep -q .; then
  echo "App bundle contains symlinks; bundled helpers must be copied, not linked."
  find "$APP_BUNDLE/Contents" -type l
  exit 1
fi

if grep -RIl "$ROOT_DIR" "$APP_BUNDLE" >/dev/null 2>&1; then
  echo "App bundle contains a literal project path:"
  grep -RIl "$ROOT_DIR" "$APP_BUNDLE" 2>/dev/null
  exit 1
fi

echo "App bundle helper check passed."
