cask "pano-gecmisi" do
  version "1.3"
  sha256 "2aa9183b9a009857a9a536d4dcf483635fa435a3f369af48697f36f54d7b633b"

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
