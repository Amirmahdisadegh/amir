#!/usr/bin/env bash
#
# Builds the sing-box mobile core (libbox.aar) for Android via gomobile and
# drops it into app/libs/. Pinned to sing-box v1.12.4, whose libbox exposes the
# simple NewService(config, platformInterface) API used by AnarVpnService.
#
# Requirements:
#   - Go (any recent version)
#   - Android SDK + NDK (set ANDROID_NDK_HOME, or install the NDK via Android
#     Studio -> SDK Tools -> NDK; this script auto-detects the default location)
#
set -euo pipefail

SINGBOX_VERSION="v1.12.4"
TAGS="with_quic,with_utls,with_clash_api,with_gvisor,with_wireguard"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
OUT="$PROJECT_DIR/app/libs"
mkdir -p "$OUT"

command -v go >/dev/null 2>&1 || { echo "error: Go is not installed (https://go.dev/dl/)"; exit 1; }

# Auto-detect the Android SDK/NDK if not provided.
if [[ -z "${ANDROID_NDK_HOME:-}" ]]; then
  DEF_SDK="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
  if [[ -d "$DEF_SDK/ndk" ]]; then
    export ANDROID_HOME="$DEF_SDK"
    export ANDROID_NDK_HOME="$DEF_SDK/ndk/$(ls "$DEF_SDK/ndk" | sort -V | tail -1)"
  fi
fi
if [[ -z "${ANDROID_NDK_HOME:-}" || ! -d "${ANDROID_NDK_HOME:-/nonexistent}" ]]; then
  echo "error: Android NDK not found. Install it in Android Studio (SDK Tools -> NDK),"
  echo "       or set ANDROID_NDK_HOME to its path."
  exit 1
fi
echo "==> Using NDK: $ANDROID_NDK_HOME"

# gomobile needs a real JDK (javac). macOS ships only a stub; prefer Android
# Studio's bundled JetBrains Runtime if no JDK is on PATH.
if ! javac -version >/dev/null 2>&1; then
  for jbr in "/Applications/Android Studio.app/Contents/jbr/Contents/Home" \
             "$HOME/Applications/Android Studio.app/Contents/jbr/Contents/Home" \
             "/Applications/Android Studio Preview.app/Contents/jbr/Contents/Home"; do
    if [[ -x "$jbr/bin/javac" ]]; then
      export JAVA_HOME="$jbr"
      export PATH="$JAVA_HOME/bin:$PATH"
      break
    fi
  done
fi
if ! javac -version >/dev/null 2>&1; then
  echo "error: no JDK found (javac). Install a JDK, or Android Studio (which bundles one)."
  exit 1
fi
echo "==> Using JDK: $(command -v javac)"

echo "==> Installing gomobile..."
go install golang.org/x/mobile/cmd/gomobile@latest
go install golang.org/x/mobile/cmd/gobind@latest
export PATH="$PATH:$(go env GOPATH)/bin"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
echo "==> Fetching sing-box $SINGBOX_VERSION..."
git clone --depth 1 -b "$SINGBOX_VERSION" https://github.com/SagerNet/sing-box "$WORK/sing-box"

# pidfd_android.go uses //go:linkname to os.checkPidfdOnce, a symbol removed in
# Go 1.25+. The workaround it provided is unnecessary on modern Go, so neuter the
# file to make the build work with any Go version.
echo "==> Patching pidfd_android.go for current Go..."
echo 'package libbox' > "$WORK/sing-box/experimental/libbox/pidfd_android.go"

cd "$WORK/sing-box"
# Newer gomobile requires golang.org/x/mobile in the module's dependency graph.
echo "==> Adding gomobile bind dependency to the module..."
go get golang.org/x/mobile/bind
echo "==> gomobile init..."
gomobile init
echo "==> Building libbox.aar (this takes a few minutes)..."
gomobile bind -v -target=android -androidapi 21 \
  -tags "$TAGS" \
  -o "$OUT/libbox.aar" \
  ./experimental/libbox

echo
echo "==> Done: $OUT/libbox.aar"
echo "Now open AnarAndroid in Android Studio, let Gradle sync, and Run."
