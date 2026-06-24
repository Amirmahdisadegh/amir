#!/usr/bin/env bash
#
# Builds the StormDNS Go client as a universal (arm64 + x86_64) macOS binary and
# drops it into WhiteDNS/Resources/stormdns so Xcode bundles it into the app.
#
# Requirements: Go 1.25+, git, and (for the universal binary) the `lipo` tool
# that ships with the Xcode command-line tools.
#
# Usage:
#   ./Scripts/build-core.sh                 # clone StormDNS and build
#   STORMDNS_SRC=/path/to/StormDNS ./Scripts/build-core.sh   # use a local checkout
#
set -euo pipefail

REPO_URL="https://github.com/nullroute1970/StormDNS.git"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
OUT_DIR="$PROJECT_DIR/WhiteDNS/Resources"
OUT_BIN="$OUT_DIR/stormdns"

command -v go >/dev/null 2>&1 || { echo "error: Go is not installed (https://go.dev/dl/)"; exit 1; }

# Obtain the source.
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
if [[ -n "${STORMDNS_SRC:-}" ]]; then
  echo "==> Using local StormDNS source: $STORMDNS_SRC"
  SRC="$STORMDNS_SRC"
else
  echo "==> Cloning StormDNS…"
  git clone --depth 1 "$REPO_URL" "$WORK/StormDNS"
  SRC="$WORK/StormDNS"
fi

mkdir -p "$OUT_DIR"

build() {
  local arch="$1" out="$2"
  echo "==> Building darwin/$arch…"
  ( cd "$SRC" && CGO_ENABLED=0 GOOS=darwin GOARCH="$arch" \
      go build -trimpath -ldflags="-s -w" -o "$out" ./cmd/client )
}

ARM="$WORK/stormdns_arm64"
AMD="$WORK/stormdns_amd64"
build arm64 "$ARM"
build amd64 "$AMD"

if command -v lipo >/dev/null 2>&1; then
  echo "==> Creating universal binary with lipo…"
  lipo -create "$ARM" "$AMD" -output "$OUT_BIN"
else
  echo "==> lipo not found; installing arm64 build only (Apple Silicon)."
  echo "    Install Xcode command-line tools for a universal binary: xcode-select --install"
  cp "$ARM" "$OUT_BIN"
fi

chmod +x "$OUT_BIN"
echo "==> Done: $OUT_BIN"
file "$OUT_BIN" 2>/dev/null || true
echo
echo "Next:  cd \"$PROJECT_DIR\" && xcodegen generate && open WhiteDNS.xcodeproj"
