#!/bin/zsh
set -euo pipefail

bundle_root="${1:-.build/release/Sameko IDE.app}"
bundle_contents="$bundle_root/Contents"

swift build -c release
mkdir -p "$bundle_contents/MacOS" "$bundle_contents/Resources"
cp .build/release/SamekoMac "$bundle_contents/MacOS/SamekoMac"
cp Info.plist "$bundle_contents/Info.plist"
cp ../src/assets/icon.icns "$bundle_contents/Resources/Icon.icns"

echo "Created $bundle_root"
