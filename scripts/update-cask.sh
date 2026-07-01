#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="${VERSION:-0.1.1}"
PKG_PATH="${1:-"$ROOT_DIR/dist/VirtConnector-${VERSION}-signed.pkg"}"
CASK_PATH="$ROOT_DIR/Casks/virt-connector.rb"

if [[ ! -f "$PKG_PATH" ]]; then
  echo "package not found: $PKG_PATH" >&2
  exit 1
fi

SHA256="$(shasum -a 256 "$PKG_PATH" | awk '{print $1}')"

python3 - "$CASK_PATH" "$VERSION" "$SHA256" <<'PY'
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
version = sys.argv[2]
sha256 = sys.argv[3]
text = path.read_text()
lines = []
for line in text.splitlines():
    stripped = line.strip()
    if stripped.startswith("version "):
        lines.append(f'  version "{version}"')
    elif stripped.startswith("sha256 "):
        lines.append(f'  sha256 "{sha256}"')
    else:
        lines.append(line)
path.write_text("\n".join(lines) + "\n")
PY

echo "Updated $CASK_PATH for version $VERSION"
