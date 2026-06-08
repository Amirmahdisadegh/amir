#!/bin/bash
set -e
echo "⚙️  White DNS — Setup"
if ! command -v xcodegen &>/dev/null; then
    echo "📦 Installing xcodegen..."
    brew install xcodegen
fi
echo "🔨 Generating Xcode project..."
xcodegen generate
echo "✅ Opening in Xcode..."
open WhiteDNS.xcodeproj
