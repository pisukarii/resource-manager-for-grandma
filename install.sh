#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

xcodegen generate

xcodebuild -project GrandMAResourceManager.xcodeproj -scheme GrandMAResourceManager \
  -configuration Release -destination 'platform=macOS' build

APP_NAME="grandMA Resource Manager.app"
RELEASE_APP=$(find ~/Library/Developer/Xcode/DerivedData -maxdepth 1 -name "GrandMAResourceManager-*" | head -1)/Build/Products/Release/$APP_NAME

pkill -f "grandMA Resource Manager" 2>/dev/null || true
sleep 1
rm -rf "/Applications/$APP_NAME"
cp -R "$RELEASE_APP" /Applications/

echo "Installed to /Applications/$APP_NAME"
open "/Applications/$APP_NAME"
