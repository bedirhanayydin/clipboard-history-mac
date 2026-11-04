import Cocoa

/// Menü çubuğu ikonu: uygulama ikonundaki üst üste kartların sade hali.
/// "Template" olduğu için açık/koyu menü çubuğuna kendiliğinden uyar.
enum MenuBarIcon {
    static func make(size: CGFloat = 18) -> NSImage {
        let img = NSImage(size: NSSize(width: size, height: size), flipped: false) { _ in
            guard let ctx = NSGraphicsContext.current else { return false }
            let k = size / 18
            func rr(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ r: CGFloat) -> NSBezierPath {
                NSBezierPath(roundedRect: NSRect(x: x * k, y: y * k, width: w * k, height: h * k),
                             xRadius: r * k, yRadius: r * k)
            }
            NSColor.black.setFill()
            NSColor.black.setStroke()

            // arkadaki kart (sadece çerçeve)
            let back = rr(6.3, 5.3, 9.7, 11.2, 2.4)
            back.lineWidth = 1.4 * k
            back.stroke()

            // öndeki kartın çevresini boşalt ki arka kart çizgisi karışmasın
            ctx.compositingOperation = .clear
            rr(0.9, 0.4, 12.6, 14.2, 3.2).fill()

            // öndeki kart (dolu)
            ctx.compositingOperation = .sourceOver
            rr(2, 1.5, 10.4, 12, 2.4).fill()

            // kartın üzerindeki satırlar (oyulmuş)
            ctx.compositingOperation = .destinationOut
            for (i, w) in [6.4, 4.2, 5.4].enumerated() {
                rr(4, 9.9 - CGFloat(i) * 2.7, w, 1.4, 0.7).fill()
            }
            ctx.compositingOperation = .sourceOver
            return true
        }
        img.isTemplate = true
        img.accessibilityDescription = "Pano Geçmişi"
        return img
    }
}
