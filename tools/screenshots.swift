// README ekran görüntülerini örnek verilerle üretir.
// Kullanım:  ./tools/screenshots.sh   (çıktı: docs/screenshots/)
import Cocoa
import SwiftUI

@main
struct Screenshots {
    static func main() {
        let out = CommandLine.arguments[1]
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        app.applicationIconImage = NSImage(contentsOfFile: CommandLine.arguments[2])
        MainActor.assumeIsolated { run(out) }
    }

    @MainActor
    static func run(_ out: String) {
        let store = ClipStore(preview: sampleClips(out))
        store.excluded = [
            ExcludedApp(bundleID: "com.apple.keychainaccess", name: "Anahtar Zinciri Erişimi"),
            ExcludedApp(bundleID: "com.apple.Passwords", name: "Parolalar"),
            ExcludedApp(bundleID: "com.apple.Terminal", name: "Terminal"),
        ]

        func picker(_ tab: PickerTab, _ q: String) -> some View {
            let m = PickerModel()
            m.staticLayout = true
            m.tab = tab
            m.query = q
            return PickerView(model: m, store: store) { _ in }
        }

        save(render(picker(.recent, ""), dark: false), "\(out)/picker.png")
        save(render(picker(.pinned, ""), dark: true), "\(out)/favorites.png")
        save(render(picker(.recent, "safari:swift"), dark: false), "\(out)/filter.png")

        let hk = HotKeyManager()
        save(window(GeneralTab(store: store, hotkeys: hk), size: NSSize(width: 540, height: 430),
                    title: "Pano Geçmişi Ayarları"), "\(out)/settings.png")
        save(window(ExcludedTab(store: store), size: NSSize(width: 540, height: 430),
                    title: "Pano Geçmişi Ayarları"), "\(out)/excluded.png")

        let ob = OnboardingModel()
        ob.axTrusted = true
        save(window(OnboardingView(model: ob), size: NSSize(width: 540, height: 600), title: nil), "\(out)/welcome.png")

        try? FileManager.default.removeItem(atPath: "\(out)/sample-image.png")
    }

    // MARK: Örnek veriler (gerçek kişisel bilgi içermez)

    static func sampleClips(_ out: String) -> [Clip] {
        let imgPath = "\(out)/sample-image.png"
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1200, pixelsHigh: 800, bitsPerSample: 8,
                                   samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                   colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        NSGradient(colors: [.systemTeal, .systemIndigo])!.draw(in: NSRect(x: 0, y: 0, width: 1200, height: 800), angle: 35)
        NSColor.white.withAlphaComponent(0.92).setFill()
        NSBezierPath(roundedRect: NSRect(x: 150, y: 150, width: 900, height: 500), xRadius: 40, yRadius: 40).fill()
        ("Sepet ekranı tasarımı" as NSString).draw(at: NSPoint(x: 230, y: 380), withAttributes: [
            .font: NSFont.boldSystemFont(ofSize: 80), .foregroundColor: NSColor.systemIndigo])
        NSGraphicsContext.restoreGraphicsState()
        try? rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: imgPath))

        let now = Date()
        func c(_ t: String, _ min: Double, _ id: String?, _ name: String?, pin: Double? = nil) -> Clip {
            var x = Clip(text: t, date: now.addingTimeInterval(-min * 60), appBundleID: id, appName: name)
            if let p = pin { x.pinnedAt = now.addingTimeInterval(-p * 60) }
            return x
        }
        var img = Clip(text: "", date: now.addingTimeInterval(-60), appBundleID: "com.apple.Safari", appName: "Safari",
                       imageFile: imgPath, imageHash: "sample", imageWidth: 1200, imageHeight: 800)
        img.pinnedAt = now

        return [
            c("Toplantı yarın saat 14:00'te, ikinci kattaki salonda.\nGündem:\n- Q4 hedefleri\n- Yeni sepet servisi\n- Kampanya takvimi",
              0.2, "com.apple.Notes", "Notlar"),
            c("https://github.com/bedirhanayydin/clipboard-history-mac", 3, "com.apple.Safari", "Safari"),
            c("git commit -m \"fix: sepet toplamı yanlış hesaplanıyordu\"", 12, "com.apple.Terminal", "Terminal"),
            c("https://developer.apple.com/documentation/swiftui", 30, "com.apple.Safari", "Safari"),
            c("+90 555 000 00 00", 95, nil, nil),
            c("Merhaba, siparişiniz kargoya verildi. Takip numarası: 1Z999AA10123456784", 200, "com.apple.mail", "Mail"),
            img,
            c("Örnek Mah. Deneme Sok. No: 1, 34000 İstanbul", 3000, "com.apple.Notes", "Notlar", pin: 10),
            c("Saygılarımla,\nBedirhan Aydın", 5000, "com.apple.mail", "Mail", pin: 20),
            c("ornek@eposta.com", 6000, "com.apple.mail", "Mail", pin: 30),
        ]
    }

    // MARK: Çizim

    /// Saf SwiftUI görünümü (seçici pencere)
    @MainActor
    static func render<V: View>(_ v: V, dark: Bool) -> NSImage {
        let r = ImageRenderer(content: v.environment(\.colorScheme, dark ? .dark : .light))
        r.scale = 2
        return backdrop(r.nsImage!, cornerRadius: 24, dark: dark)
    }

    /// AppKit kontrolleri içeren görünümler (Ayarlar, Karşılama): gerçek pencerede çizip yakalar
    @MainActor
    static func window<V: View>(_ v: V, size: NSSize, title: String?) -> NSImage {
        let titleH: CGFloat = title == nil ? 0 : 28
        NSApp.appearance = NSAppearance(named: .aqua)
        let host = NSHostingView(rootView: v
            .frame(width: size.width, height: size.height)
            .background(Color(nsColor: .windowBackgroundColor))
            .environment(\.colorScheme, .light))
        host.appearance = NSAppearance(named: .aqua)
        let w = NSWindow(contentRect: NSRect(x: -4000, y: -4000, width: size.width, height: size.height),
                         styleMask: [.borderless], backing: .buffered, defer: false)
        w.appearance = NSAppearance(named: .aqua)
        w.contentView = host
        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        for _ in 0..<6 { RunLoop.main.run(until: Date().addingTimeInterval(0.1)) }
        host.layoutSubtreeIfNeeded()
        host.display()
        let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds)!
        host.cacheDisplay(in: host.bounds, to: rep)
        w.orderOut(nil)

        // pencere çerçevesi + başlık çubuğu
        let full = NSSize(width: size.width, height: size.height + titleH)
        let img = NSImage(size: full)
        img.lockFocus()
        NSColor.windowBackgroundColor.setFill()
        NSRect(origin: .zero, size: full).fill()
        rep.draw(in: NSRect(x: 0, y: 0, width: size.width, height: size.height))
        if let t = title {
            NSColor(white: 0.97, alpha: 1).setFill()
            NSRect(x: 0, y: size.height, width: size.width, height: titleH).fill()
            for (i, col) in [NSColor.systemRed, .systemYellow, .systemGreen].enumerated() {
                col.setFill()
                NSBezierPath(ovalIn: NSRect(x: 12 + CGFloat(i) * 20, y: size.height + 8, width: 12, height: 12)).fill()
            }
            let p = NSMutableParagraphStyle(); p.alignment = .center
            (t as NSString).draw(in: NSRect(x: 0, y: size.height + 6, width: size.width, height: 18), withAttributes: [
                .font: NSFont.boldSystemFont(ofSize: 13), .foregroundColor: NSColor.labelColor, .paragraphStyle: p])
        }
        img.unlockFocus()
        return backdrop(img, cornerRadius: 12, dark: false, scale: 2)
    }

    /// Görüntüyü yuvarlatıp gölgeli, renkli bir masaüstü zeminine yerleştirir
    static func backdrop(_ image: NSImage, cornerRadius: CGFloat, dark: Bool, scale: CGFloat = 1) -> NSImage {
        let inner = NSSize(width: image.size.width * scale, height: image.size.height * scale)
        let pad: CGFloat = 56 * (image.size.width > 1000 ? 2 : 1) * (scale > 1 ? 2 : 1) / 2
        let size = NSSize(width: inner.width + pad * 2, height: inner.height + pad * 2)
        let out = NSImage(size: size)
        out.lockFocus()
        let colors: [NSColor] = dark
            ? [NSColor(red: 0.10, green: 0.12, blue: 0.30, alpha: 1), NSColor(red: 0.30, green: 0.12, blue: 0.40, alpha: 1)]
            : [NSColor(red: 0.55, green: 0.70, blue: 1.00, alpha: 1), NSColor(red: 0.80, green: 0.62, blue: 0.98, alpha: 1)]
        NSGradient(colors: colors)!.draw(in: NSRect(origin: .zero, size: size), angle: -35)

        let r = NSRect(x: pad, y: pad, width: inner.width, height: inner.height)
        let path = NSBezierPath(roundedRect: r, xRadius: cornerRadius * 2, yRadius: cornerRadius * 2)
        NSGraphicsContext.saveGraphicsState()
        let sh = NSShadow()
        sh.shadowColor = NSColor.black.withAlphaComponent(0.35)
        sh.shadowBlurRadius = 40
        sh.shadowOffset = NSSize(width: 0, height: -14)
        sh.set()
        NSColor.black.setFill()
        path.fill()
        NSGraphicsContext.restoreGraphicsState()
        NSGraphicsContext.saveGraphicsState()
        path.addClip()
        image.draw(in: r)
        NSGraphicsContext.restoreGraphicsState()
        out.unlockFocus()
        return out
    }

    static func save(_ img: NSImage, _ path: String) {
        guard let tiff = img.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else { return }
        try? png.write(to: URL(fileURLWithPath: path))
        print("✓ \(path)")
    }
}
