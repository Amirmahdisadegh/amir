#!/usr/bin/env bash
#
# Builds the two universal (arm64 + x86_64) macOS core binaries that Anar bundles:
#   - sing-box  : multi-protocol proxy core (VMess/VLESS/Trojan/Shadowsocks/Hysteria2/TUIC/WireGuard)
#   - stormdns  : DNS-tunneling core (optional, for WhiteDNS-style profiles)
#
# Output: Anar/Anar/Resources/{sing-box,stormdns}
#
# Requirements: Go 1.24+, git, and `lipo` (Xcode command-line tools).
#
set -euo pipefail

SINGBOX_VERSION="v1.13.13"
SINGBOX_TAGS="with_quic,with_utls,with_clash_api,with_gvisor,with_dhcp,with_wireguard,with_grpc,with_acme"
STORMDNS_REPO="https://github.com/nullroute1970/StormDNS.git"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
OUT_DIR="$PROJECT_DIR/Anar/Resources"
mkdir -p "$OUT_DIR"

command -v go >/dev/null 2>&1 || { echo "error: Go is not installed (https://go.dev/dl/)"; exit 1; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
export GOPATH="$WORK/go"

universal() { # name arm64bin amd64bin
  local name="$1" arm="$2" amd="$3"
  if command -v lipo >/dev/null 2>&1; then
    lipo -create "$arm" "$amd" -output "$OUT_DIR/$name"
  else
    echo "warning: lipo not found; bundling arm64 only for $name"
    cp "$arm" "$OUT_DIR/$name"
  fi
  chmod +x "$OUT_DIR/$name"
  file "$OUT_DIR/$name" || true
}

echo "==> Building sing-box $SINGBOX_VERSION (this downloads several Go modules)..."
build_singbox() { # goarch outfile
  CGO_ENABLED=0 GOOS=darwin GOARCH="$1" \
    go install -trimpath -ldflags="-s -w" -tags "$SINGBOX_TAGS" \
    "github.com/sagernet/sing-box/cmd/sing-box@$SINGBOX_VERSION"
  cp "$GOPATH/bin/darwin_$1/sing-box" "$2" 2>/dev/null || cp "$GOPATH/bin/sing-box" "$2"
}
build_singbox arm64 "$WORK/singbox_arm64"
build_singbox amd64 "$WORK/singbox_amd64"
universal sing-box "$WORK/singbox_arm64" "$WORK/singbox_amd64"

echo "==> Building stormdns (DNS-tunnel core)..."
if git clone --depth 1 "$STORMDNS_REPO" "$WORK/StormDNS" 2>/dev/null; then
  ( cd "$WORK/StormDNS" && CGO_ENABLED=0 GOOS=darwin GOARCH=arm64 go build -trimpath -ldflags="-s -w" -o "$WORK/storm_arm64" ./cmd/client )
  ( cd "$WORK/StormDNS" && CGO_ENABLED=0 GOOS=darwin GOARCH=amd64 go build -trimpath -ldflags="-s -w" -o "$WORK/storm_amd64" ./cmd/client )
  universal stormdns "$WORK/storm_arm64" "$WORK/storm_amd64"
else
  echo "warning: could not clone StormDNS; skipping stormdns core (sing-box still works)."
fi

echo
echo "==> Done. Cores in: $OUT_DIR"
echo "Next:  cd \"$PROJECT_DIR\" && xcodegen generate && open Anar.xcodeproj"
