#!/bin/zsh
set -eu
cd "${0:A:h}"
DEST="${1:-../../outputs}"
mkdir -p "$DEST"
DEST="${DEST:A}"
swift build -c release
APP="$DEST/AudioSplit X.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/AudioSplitX "$APP/Contents/MacOS/AudioSplitX"
cp Packaging/Info.plist "$APP/Contents/Info.plist"
cp Packaging/SoundRouter-LICENSE.txt "$APP/Contents/Resources/"
if [[ -f Packaging/AppIcon.icns ]]; then cp Packaging/AppIcon.icns "$APP/Contents/Resources/"; fi
IDENTITY="${AUDIOSPLIT_SIGN_IDENTITY:--}"
codesign --force --options runtime --sign "$IDENTITY" "$APP"
codesign --verify --strict --verbose=2 "$APP"
echo "$APP"
