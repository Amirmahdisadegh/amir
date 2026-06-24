#!/usr/bin/env bash
#
# Builds the sing-box mobile core (libbox.aar) for Android via gomobile and
# drops it into app/libs/. Pinned to sing-box v1.12.4, whose libbox exposes the
# simple NewService(config, platformInterface) API used by AnarVpnService.
#
# Requirements:
#   - Go 1.23+
#   - Android SDK + NDK (set ANDROID_HOME / ANDROID_NDK_HOME, or install via
#     Android Studio: SDK Manager -> SDK Tools -> NDK (Side by side))
#
set -euo pipefail

SINGBOX_VERSION="v1.12.4"
TAGS="with_quic,with_utls,with_clash_api,with_gvisor,with_wireguard"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
OUT="$PROJECT_DIR/app/libs"
mkdir -p "$OUT"

command -v go >/dev/null 2>&1 || { echo "error: Go is not installed (https://go.dev/dl/)"; exit 1; }

if [[ -z "${ANDROID_NDK_HOME:-}" && -z "${ANDROID_HOME:-}" ]]; then
  echo "warning: ANDROID_NDK_HOME / ANDROID_HOME not set."
  echo "Install the NDK in Android Studio (SDK Tools -> NDK) and export, e.g.:"
  echo '  export ANDROID_HOME=$HOME/Library/Android/sdk'
  echo '  export ANDROID_NDK_HOME=$ANDROID_HOME/ndk/<version>'
fi

echo "==> Installing gomobile…"
go install golang.org/x/mobile/cmd/gomobile@latest
go install golang.org/x/mobile/cmd/gobind@latest
export PATH="$PATH:$(go env GOPATH)/bin"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
echo "==> Fetching sing-box $SINGBOX_VERSION…"
git clone --depth 1 -b "$SINGBOX_VERSION" https://github.com/SagerNet/sing-box "$WORK/sing-box"

cd "$WORK/sing-box"
echo "==> gomobile init…"
gomobile init
echo "==> Building libbox.aar (this takes a few minutes)…"
gomobile bind -v -target=android -androidapi 21 \
  -tags "$TAGS" \
  -o "$OUT/libbox.aar" \
  ./experimental/libbox

echo
echo "==> Done: $OUT/libbox.aar"
echo "Now open AnarAndroid in Android Studio, let Gradle sync, and Run."
