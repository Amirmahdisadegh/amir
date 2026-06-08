#!/bin/bash
set -e

echo "⚙️  White DNS — Setup"

# Install xcodegen if missing
if ! command -v xcodegen &>/dev/null; then
    echo "📦 Installing xcodegen..."
    brew install xcodegen
fi

# Generate Xcode project
echo "🔨 Generating Xcode project..."
xcodegen generate

# Open in Xcode
echo "✅ Opening in Xcode..."
open WhiteDNS.xcodeproj
