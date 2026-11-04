import Cocoa
import Carbon
import UniformTypeIdentifiers

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    let store = ClipStore()
    let hotkeys = HotKeyManager()
    lazy var picker = PickerController(store: store)
    lazy var settings = SettingsWindowController(store: store, hotkeys: hotkeys)
    let onboarding = OnboardingWindowController()

    private var statusItem: NSStatusItem!
    private let pasteboard = NSPasteboard.general
    private var lastChange = NSPasteboard.general.changeCount
    private var warnedThisSession = false
    private let defaults = UserDefaults.standard

    func applicationDidFinishLaunching(_ notification: Notification) {
        if AppMover.moveIfNeeded() { return }

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = MenuBarIcon.make()
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu

        picker.onPick = { [weak self] id in self?.use(id) }
        hotkeys.onPress = { [weak self] in
            self?.showPicker()
            self?.onboarding.shortcutPressed()
        }

        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in self?.poll() }

        // İlk açılışta ya da izin kaybolduysa (ör. güncellemeden sonra) karşılama penceresi
        if !defaults.bool(forKey: "onboarded") || !AXIsProcessTrusted() {
            onboarding.show(shortcut: hotkeys.display)
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        settings.show()   // Uygulamalar'dan tekrar açılınca Ayarlar'ı göster
        return true
    }

    func showPicker() { picker.toggle(shortcut: hotkeys.display) }

    // MARK: - Panoyu izleme

    private func poll() {
        guard pasteboard.changeCount != lastChange else { return }
        lastChange = pasteboard.changeCount

        let front = NSWorkspace.shared.frontmostApplication
        if store.isExcluded(front?.bundleIdentifier) { return }

        let types = pasteboard.types ?? []
        // Şifre yöneticilerinin "gizli" ya da "geçici" işaretlediği kopyaları kaydetme
        for t in ["org.nspasteboard.ConcealedType", "org.nspasteboard.TransientType"]
        where types.contains(NSPasteboard.PasteboardType(t)) { return }

        if !types.contains(.fileURL),
           let text = pasteboard.string(forType: .string),
           !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            store.addText(text, from: front)
            return
        }
        if let (png, w, h) = readImage(types) {
            store.addImage(png: png, width: w, height: h, from: front)
        }
    }

    /// Panodaki resmi (ekran görüntüsü, tarayıcıdan "Resmi Kopyala" ya da Finder'da resim dosyası) PNG olarak okur
    private func readImage(_ types: [NSPasteboard.PasteboardType]) -> (Data, Int, Int)? {
        var data: Data?
        if types.contains(.fileURL) {
            let opts: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingContentsConformToTypes: [UTType.image.identifier]]
            if let url = (pasteboard.readObjects(forClasses: [NSURL.self], options: opts) as? [URL])?.first {
                data = try? Data(contentsOf: url)
            }
        } else {
            data = pasteboard.data(forType: .png) ?? pasteboard.data(forType: .tiff)
        }
        guard let d = data, d.count < 40_000_000,
              let rep = NSBitmapImageRep(data: d),
              let png = rep.representation(using: .png, properties: [:]) else { return nil }
        return (png, rep.pixelsWide, rep.pixelsHigh)
    }

    // MARK: - Kullanma (panoya koy + yapıştır)

    private func use(_ id: UUID) {
        guard let clip = store.clip(id) else { return }
        store.touch(id)

        pasteboard.clearContents()
        if clip.isImage, let f = clip.imageFile, let png = try? Data(contentsOf: ClipImages.url(for: f)) {
            let item = NSPasteboardItem()
            item.setData(png, forType: .png)
            if let tiff = NSImage(data: png)?.tiffRepresentation { item.setData(tiff, forType: .tiff) }
            pasteboard.writeObjects([item])
        } else {
            pasteboard.setString(clip.text, forType: .string)
        }
        lastChange = pasteboard.changeCount

        if AXIsProcessTrusted() {
            // Pencere kapanıp odak yazdığın yere dönsün, sonra ⌘V gönder
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { self.sendPaste() }
        } else if !warnedThisSession {
            warnedThisSession = true
            onboarding.show(shortcut: hotkeys.display)
        }
    }

    private func sendPaste() {
        let src = CGEventSource(stateID: .combinedSessionState)
        let v = CGKeyCode(kVK_ANSI_V)
        let down = CGEvent(keyboardEventSource: src, virtualKey: v, keyDown: true)
        let up = CGEvent(keyboardEventSource: src, virtualKey: v, keyDown: false)
        down?.flags = .maskCommand
        up?.flags = .maskCommand
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }

    // MARK: - Menü çubuğu menüsü

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let open = NSMenuItem(title: "Geçmişi aç", action: #selector(openPicker), keyEquivalent: "")
        open.target = self
        open.image = NSImage(systemSymbolName: "list.bullet.rectangle", accessibilityDescription: nil)
        menu.addItem(open)

        let info = NSMenuItem(title: hotkeys.isRegistered
                              ? "\(hotkeys.display) ile her yerden aç"
                              : "Kısayol çalışmıyor, Ayarlar'dan değiştir",
                              action: nil, keyEquivalent: "")
        info.isEnabled = false
        menu.addItem(info)

        if !AXIsProcessTrusted() {
            let ax = NSMenuItem(title: "Direkt yapıştırma için izin ver…", action: #selector(askAX), keyEquivalent: "")
            ax.target = self
            ax.image = NSImage(systemSymbolName: "exclamationmark.triangle", accessibilityDescription: nil)
            menu.addItem(ax)
        }

        menu.addItem(.separator())
        let prefs = NSMenuItem(title: "Ayarlar…", action: #selector(openSettings), keyEquivalent: ",")
        prefs.target = self
        prefs.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: nil)
        menu.addItem(prefs)

        menu.addItem(.separator())
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        let sign = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        let attr = NSMutableAttributedString(string: "Pano Geçmişi \(version)  ·  ", attributes: [
            .font: NSFont.systemFont(ofSize: 11), .foregroundColor: NSColor.tertiaryLabelColor])
        attr.append(NSAttributedString(string: "Bedirhan Aydın", attributes: [
            .font: NSFont(name: "Snell Roundhand", size: 14) ?? NSFont.systemFont(ofSize: 11),
            .foregroundColor: NSColor.secondaryLabelColor]))
        sign.attributedTitle = attr
        sign.isEnabled = false
        menu.addItem(sign)
        menu.addItem(NSMenuItem(title: "Çıkış", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
    }

    @objc private func openPicker() {
        // menü kapandıktan sonra aç
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { self.showPicker() }
    }

    @objc private func openSettings() { settings.show() }
    @objc private func askAX() { onboarding.show(shortcut: hotkeys.display) }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
