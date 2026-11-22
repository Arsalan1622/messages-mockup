#!/bin/sh
# Decode binary assets stored as base64 text (the GitHub snapshot push only
# carries UTF-8 files, so binaries travel as .b64 and are restored here).
# Run from the repo root, before `flutter build`.
set -e
cd "$(dirname "$0")/.."

# Git does not track empty directories, so the mipmap folders (and the
# gradle wrapper folder) may not exist in a fresh checkout — create them
# before writing decoded files into them.
mkdir -p android/gradle/wrapper
for d in mdpi hdpi xhdpi xxhdpi xxxhdpi; do
  mkdir -p "android/app/src/main/res/mipmap-$d"
done

base64 -d tools/assets/gradle-wrapper.jar.b64 > android/gradle/wrapper/gradle-wrapper.jar
for d in mdpi hdpi xhdpi xxhdpi xxxhdpi; do
  base64 -d "tools/assets/ic_launcher-$d.png.b64" > "android/app/src/main/res/mipmap-$d/ic_launcher.png"
done

echo "Decoded binary assets:"
ls -la android/gradle/wrapper/gradle-wrapper.jar android/app/src/main/res/mipmap-*/ic_launcher.png
