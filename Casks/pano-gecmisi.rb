cask "pano-gecmisi" do
  version "1.4"
  sha256 "d1840fc38ae0237dcb411a7dfae20e79cde6a1ecd75075ee106e69a6633e177f"

  url "https://raw.githubusercontent.com/bedirhanayydin/clipboard-history-mac/main/dist/PanoGecmisi-#{version}.dmg"
  name "Pano Geçmişi"
  desc "Menu bar clipboard history: last copied texts and images, paste with a shortcut"
  homepage "https://github.com/bedirhanayydin/clipboard-history-mac"

  depends_on macos: :sonoma

  app "Pano Geçmişi.app"

  # Uygulama Apple Developer ID ile imzalı değil; brew ile kuranlar
  # "Yine de Aç" adımıyla uğraşmasın diye karantina işareti kaldırılır.
  postflight_steps do
    run "/usr/bin/xattr",
        args:           ["-dr", "com.apple.quarantine", "{{appdir}}/Pano Geçmişi.app"],
        writable_paths: ["Pano Geçmişi.app"],
        writable_base:  :appdir
  end

  uninstall quit: "com.bedirhan.panogecmisi"

  zap trash: [
    "~/Library/Application Support/PanoGecmisi",
    "~/Library/Preferences/com.bedirhan.panogecmisi.plist",
  ]
end
