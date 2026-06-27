#!/usr/bin/env bash
#
# Builds a release "Amir V2ray.app" and packages it into a distributable .dmg
# (drag-to-Applications). Run on a Mac with Xcode + XcodeGen.
#
#   cd Anar && ./Scripts/package.sh
#
# Output: Amir V2ray.dmg  (in the project folder)
#
# NOTE: the app is NOT notarized (that needs a paid Apple Developer ID). On
# another Mac, the first launch shows a Gatekeeper warning — see the printed
# instructions at the end.
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_DIR"

APP_NAME="Amir V2ray"
DMG="$PROJECT_DIR/$APP_NAME.dmg"

command -v xcodebuild >/dev/null 2>&1 || { echo "error: Xcode is required"; exit 1; }
command -v xcodegen   >/dev/null 2>&1 || { echo "error: brew install xcodegen"; exit 1; }

# 1) Cores + rule-sets must be present before bundling.
if [[ ! -f "Anar/Resources/sing-box" ]]; then
  echo "==> Building cores (sing-box / stormdns / rule-sets)..."
  ./Scripts/build-cores.sh
fi

# 2) Generate the Xcode project and build Release.
echo "==> Generating project..."
xcodegen generate
echo "==> Building Release (this can take a minute)..."
rm -rf .build
xcodebuild -project Anar.xcodeproj -scheme Anar -configuration Release \
  -derivedDataPath .build CODE_SIGNING_ALLOWED=NO build >/dev/null

APP="$PROJECT_DIR/.build/Build/Products/Release/$APP_NAME.app"
[[ -d "$APP" ]] || { echo "error: build did not produce $APP"; exit 1; }

# 3) Ad-hoc sign so macOS doesn't flag a broken signature (still not notarized).
echo "==> Ad-hoc signing..."
codesign --force --deep --sign - "$APP" 2>/dev/null || true

# 4) Build the .dmg with an Applications shortcut.
echo "==> Creating $APP_NAME.dmg..."
STAGE="$(mktemp -d)"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
rm -f "$DMG"
hdiutil create -volname "$APP_NAME" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
rm -rf "$STAGE"

echo
echo "==> Done:  $DMG"
echo
echo "To install: open the .dmg and drag "$APP_NAME" to Applications."
echo "First launch on another Mac (unsigned app):"
echo "  - Right-click the app -> Open -> Open, OR"
echo "  - System Settings -> Privacy & Security -> \"Open Anyway\", OR"
echo "  - Terminal:  xattr -dr com.apple.quarantine \"/Applications/$APP_NAME.app\""
