# Pano Geçmişi — Clipboard History for macOS

Son kopyaladığın 10 veya 20 şeyi (metin ve resim) saklayan, menü çubuğunda çalışan küçük bir macOS uygulaması. Bir yerde yazarken **⌃⌘V**'ye bas, listeden seç, direkt yapıştırsın.

*A small menu bar app that keeps your last 10 or 20 copied items (text and images). Press **⌃⌘V** anywhere, pick one, and it is pasted right where you are typing.*

## Özellikler

- **⌃⌘V** ile yazı imlecinin hemen altında açılan, Liquid Glass görünümlü seçici pencere
- **Son kopyalananlar** ve **Sık kullanılanlar** sekmeleri (⌘P ile sabitle, sabitlenenler hiç silinmez)
- Metin ve **resim** desteği (ekran görüntüleri, tarayıcıdan kopyalanan resimler)
- Yazarak arama; `safari:` gibi **uygulamaya göre filtre**, `resim:` ile sadece resimler
- Her kaydın hangi uygulamadan ve ne zaman kopyalandığı, sağda tam önizleme
- **Hariç tutulan uygulamalar**: seçtiğin uygulamalardan kopyalananlar kaydedilmez
- Şifre yöneticilerinden kopyalanan şifreler kaydedilmez
- Değiştirilebilir kısayol, Mac açılınca otomatik başlatma
- Her şey sadece senin Mac'inde saklanır, hiçbir yere gönderilmez

## Kurulum

1. [Releases](https://github.com/bedirhanayydin/clipboard-history-mac/releases) sayfasından son `PanoGecmisi-x.y.dmg` dosyasını indir.
2. DMG'yi aç, **Pano Geçmişi**'ne çift tıkla.
3. macOS "doğrulanamadı" derse (sadece ilk seferde): **Bitti** → Sistem Ayarları → Gizlilik ve Güvenlik → en altta **Yine de Aç**.
4. Gerisini uygulama kendisi gösterir: Uygulamalar klasörüne taşıma, yapıştırma izni, otomatik başlatma.

Gereksinim: macOS 14 veya üstü (Apple Silicon ve Intel).

## Kısayollar

| Tuş | İş |
| --- | --- |
| ⌃⌘V | Geçmişi aç |
| ↑ ↓ · ↩ | Seç · yapıştır |
| ⌘1 … ⌘9 | Tek tuşla yapıştır |
| ⇥ | Son kopyalananlar ⇄ Sık kullanılanlar |
| ⌘P | Sık kullanılanlara sabitle / kaldır |
| ⌘⌫ | Seçileni sil |
| esc | Aramayı temizle / kapat |

## Kaynaktan derleme

Xcode Komut Satırı Araçları yeterli (Xcode projesi yok):

```bash
./build.sh            # build/Pano Geçmişi.app
./build.sh --install  # derle ve /Applications'a kur
./build.sh --dmg      # paylaşım için build/PanoGecmisi-<sürüm>.dmg
```

Apple Developer ID ile imzalamak ve notarize etmek için:

```bash
SIGN_ID="Developer ID Application: Ad Soyad (TAKIMID)" NOTARY_PROFILE="profil" ./build.sh --dmg
```

## Dosyalar

| Dosya | İçerik |
| --- | --- |
| `main.swift` | Uygulama, pano takibi, yapıştırma, menü |
| `Picker.swift` | ⌃⌘V ile açılan seçici pencere |
| `Store.swift` | Kayıtlar, resim dosyaları, hariç tutulanlar |
| `Clip.swift` | Kayıt modeli ve yardımcılar |
| `Settings.swift` | Ayarlar penceresi |
| `Onboarding.swift` | İlk açılış karşılama penceresi |
| `AppMover.swift` | Kendini Uygulamalar klasörüne taşıma |
| `HotKey.swift` | Global kısayol |
| `MenuBarIcon.swift` | Menü çubuğu ikonu |
| `tools/make_icon.swift` | Uygulama ikonunu üretir |

---

Bedirhan Aydın
