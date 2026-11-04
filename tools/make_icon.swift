// Uygulama ikonunu üretir: swift tools/make_icon.swift <çıktı.iconset klasörü>
import Cocoa

func draw(_ px: Int) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let s = CGFloat(px)
    let inset = s * 0.098                      // macOS ikon ızgarası
    let body = NSRect(x: inset, y: inset, width: s - 2 * inset, height: s - 2 * inset)
    let path = NSBezierPath(roundedRect: body, xRadius: body.width * 0.225, yRadius: body.width * 0.225)

    // gölge + degrade zemin
    NSGraphicsContext.saveGraphicsState()
    let sh = NSShadow(); sh.shadowColor = NSColor.black.withAlphaComponent(0.28)
    sh.shadowBlurRadius = s * 0.025; sh.shadowOffset = NSSize(width: 0, height: -s * 0.012); sh.set()
    NSColor.black.setFill(); path.fill()
    NSGraphicsContext.restoreGraphicsState()
    NSGradient(colors: [NSColor(red: 0.36, green: 0.42, blue: 1.0, alpha: 1),
                        NSColor(red: 0.53, green: 0.30, blue: 0.95, alpha: 1)])!.draw(in: path, angle: -60)

    // arkadaki kartlar (geçmiş)
    func card(_ dx: CGFloat, _ dy: CGFloat, _ alpha: CGFloat) {
        let w = body.width * 0.50, h = body.height * 0.58
        let r = NSRect(x: body.midX - w / 2 + dx, y: body.midY - h / 2 + dy, width: w, height: h)
        NSColor.white.withAlphaComponent(alpha).setFill()
        NSBezierPath(roundedRect: r, xRadius: w * 0.12, yRadius: w * 0.12).fill()
    }
    card(s * 0.075, s * 0.075, 0.30)
    card(s * 0.037, s * 0.037, 0.55)

    // öndeki kart + satırlar
    let w = body.width * 0.50, h = body.height * 0.58
    let front = NSRect(x: body.midX - w / 2, y: body.midY - h / 2, width: w, height: h)
    NSGraphicsContext.saveGraphicsState()
    let sh2 = NSShadow(); sh2.shadowColor = NSColor.black.withAlphaComponent(0.18)
    sh2.shadowBlurRadius = s * 0.02; sh2.shadowOffset = NSSize(width: 0, height: -s * 0.008); sh2.set()
    NSColor.white.setFill()
    NSBezierPath(roundedRect: front, xRadius: w * 0.12, yRadius: w * 0.12).fill()
    NSGraphicsContext.restoreGraphicsState()

    let lineColor = NSColor(red: 0.45, green: 0.38, blue: 0.98, alpha: 1)
    let lw = front.width * 0.64, lh = front.height * 0.075
    for (i, frac) in [1.0, 0.8, 0.9, 0.55].enumerated() {
        let y = front.maxY - front.height * 0.22 - CGFloat(i) * lh * 2.3
        let r = NSRect(x: front.minX + (front.width - lw) / 2, y: y, width: lw * frac, height: lh)
        lineColor.withAlphaComponent(i == 0 ? 1 : 0.4).setFill()
        NSBezierPath(roundedRect: r, xRadius: lh / 2, yRadius: lh / 2).fill()
    }
    NSGraphicsContext.restoreGraphicsState()
    return rep
}

let out = URL(fileURLWithPath: CommandLine.arguments[1])
try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = scale == 1 ? "icon_\(base)x\(base).png" : "icon_\(base)x\(base)@2x.png"
        try! draw(base * scale).representation(using: .png, properties: [:])!.write(to: out.appendingPathComponent(name))
    }
}
