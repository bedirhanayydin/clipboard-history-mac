#!/bin/zsh
# Kullanım:
#   ./build.sh            → build/Pano Geçmişi.app (Apple Silicon + Intel)
#   ./build.sh --install  → derler ve /Applications'a kurar
#   ./build.sh --dmg      → derler ve paylaşmak için build/PanoGecmisi-<sürüm>.dmg üretir
set -e
cd "$(dirname "$0")"

VERSION="1.3"
NAME="Pano Geçmişi"
APP="build/$NAME.app"
SOURCES=(main.swift Picker.swift Clip.swift Store.swift HotKey.swift Settings.swift MenuBarIcon.swift Onboarding.swift AppMover.swift)

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" build/obj

for arch in arm64 x86_64; do
  swiftc -O -target "$arch-apple-macos14.0" "${SOURCES[@]}" -o "build/obj/PanoGecmisi-$arch"
done
lipo -create build/obj/PanoGecmisi-arm64 build/obj/PanoGecmisi-x86_64 -output "$APP/Contents/MacOS/PanoGecmisi"

cp AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>$NAME</string>
  <key>CFBundleDisplayName</key><string>$NAME</string>
  <key>CFBundleIdentifier</key><string>com.bedirhan.panogecmisi</string>
  <key>CFBundleExecutable</key><string>PanoGecmisi</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>$VERSION</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHumanReadableCopyright</key><string>© 2026 Bedirhan Aydın</string>
</dict>
</plist>
EOF

# Apple Developer ID varsa: SIGN_ID="Developer ID Application: Ad Soyad (TAKIMID)" ./build.sh --dmg
if [[ -n "$SIGN_ID" ]]; then
  codesign --force --options runtime --timestamp -s "$SIGN_ID" "$APP"
else
  codesign --force -s - "$APP"
fi
echo "✓ Derlendi: $APP"

if [[ "$1" == "--install" ]]; then
  pkill -x PanoGecmisi 2>/dev/null || true
  sleep 0.5
  rm -rf "/Applications/$NAME.app"
  cp -R "$APP" /Applications/
  open "/Applications/$NAME.app"
  echo "✓ Kuruldu: /Applications/$NAME.app"
fi

if [[ "$1" == "--dmg" ]]; then
  DMG="build/PanoGecmisi-$VERSION.dmg"
  STAGE="build/dmg"
  rm -rf "$STAGE" "$DMG"
  mkdir -p "$STAGE"
  cp -R "$APP" "$STAGE/"
  ln -s /Applications "$STAGE/Applications"
  cp KURULUM.txt "$STAGE/Kurulum - önce bunu oku.txt"
  hdiutil create -volname "$NAME" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
  rm -rf "$STAGE"
  if [[ -n "$SIGN_ID" && -n "$NOTARY_PROFILE" ]]; then
    codesign -s "$SIGN_ID" --timestamp "$DMG"
    xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple "$DMG"
  fi
  echo "✓ Paylaşım dosyası: $DMG"
fi
