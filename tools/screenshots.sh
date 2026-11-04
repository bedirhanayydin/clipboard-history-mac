#!/bin/zsh
# README ekran görüntülerini docs/screenshots/ klasörüne üretir
set -e
cd "$(dirname "$0")/.."
mkdir -p build/obj docs/screenshots
swiftc -parse-as-library tools/screenshots.swift Picker.swift Clip.swift Store.swift HotKey.swift Settings.swift Onboarding.swift \
  -o build/obj/screenshots
build/obj/screenshots "$PWD/docs/screenshots" "$PWD/AppIcon.icns"
