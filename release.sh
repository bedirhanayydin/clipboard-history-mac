#!/bin/zsh
# Yeni sürümü yayına hazırlar:
#   1. build.sh içindeki VERSION'ı artır
#   2. ./release.sh            (derler, DMG'yi dist/'e koyar, Casks/ tarifini günceller)
#   3. git add -A && git commit -m "x.y" && git push
# Var olan build/ DMG'sini derlemeden yayınlamak için: ./release.sh --no-build
set -e
cd "$(dirname "$0")"
VERSION=$(grep -m1 '^VERSION=' build.sh | cut -d'"' -f2)
DMG="build/PanoGecmisi-$VERSION.dmg"

[[ "$1" == "--no-build" ]] || ./build.sh --dmg
[[ -f "$DMG" ]] || { echo "DMG yok: $DMG"; exit 1; }

mkdir -p dist
find dist -name "PanoGecmisi-*.dmg" -delete   # eski sürümler git geçmişinde kalır
cp "$DMG" dist/
SHA=$(shasum -a 256 "$DMG" | cut -d' ' -f1)
sed -i '' "s/^  version \".*\"/  version \"$VERSION\"/; s/^  sha256 \".*\"/  sha256 \"$SHA\"/" Casks/pano-gecmisi.rb
echo "✓ dist/PanoGecmisi-$VERSION.dmg"
echo "✓ Casks/pano-gecmisi.rb → $VERSION ($SHA)"
echo "Şimdi: git add -A && git commit -m \"$VERSION\" && git push"
