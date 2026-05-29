#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOOLS_DIR="$ROOT_DIR/Resources/Tools/darwin-arm64"

if [[ ! -d "$TOOLS_DIR" ]]; then
  echo "No bundled tools directory found at $TOOLS_DIR"
  exit 0
fi

while IFS= read -r tool; do
  if ! file "$tool" | grep -q "Mach-O"; then
    continue
  fi

  description="$(file "$tool")"
  if ! grep -Eq "arm64|arm64e" <<<"$description"; then
    echo "Unsupported bundled helper architecture: $tool"
    echo "$description"
    exit 1
  fi

  if grep -Eq "x86_64|i386" <<<"$description"; then
    echo "Intel architecture found in bundled helper: $tool"
    echo "$description"
    exit 1
  fi
done < <(find "$TOOLS_DIR" -type f -perm -111 | sort)

echo "Bundled helper architecture check passed."
