import Cocoa
import Carbon

/// Her yerden çalışan kısayol (varsayılan ⌃⌘V) ve Ayarlar'daki kısayol kaydedici
final class HotKeyManager: ObservableObject {
    @Published private(set) var display = ""
    @Published private(set) var isRecording = false
    @Published private(set) var isRegistered = false
    @Published private(set) var message: String?

    var onPress: (() -> Void)?

    private static let defaultKeyCode = UInt32(kVK_ANSI_V)
    private static let defaultModifiers = UInt32(cmdKey | controlKey)
    private static let defaultKeyName = "V"

    private let defaults = UserDefaults.standard
    private var ref: EventHotKeyRef?
    private var monitor: Any?

    var isCustom: Bool { defaults.object(forKey: "hotKeyCode") != nil }

    private var keyCode: UInt32 {
        isCustom ? UInt32(defaults.integer(forKey: "hotKeyCode")) : Self.defaultKeyCode
    }
    private var modifiers: UInt32 {
        defaults.object(forKey: "hotKeyModifiers") == nil ? Self.defaultModifiers
            : UInt32(defaults.integer(forKey: "hotKeyModifiers"))
    }
    private var keyName: String { defaults.string(forKey: "hotKeyName") ?? Self.defaultKeyName }

    init() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, userData in
            guard let userData else { return noErr }
            let me = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
            DispatchQueue.main.async { me.onPress?() }
            return noErr
        }, 1, &eventType, Unmanaged.passUnretained(self).toOpaque(), nil)

        isRegistered = register(keyCode, modifiers)
        display = Self.describe(modifiers, keyName)
    }

    // MARK: Kaydetme

    func startRecording() {
        unregister()
        message = nil
        isRecording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] e in
            self?.handle(e)
            return nil
        }
    }

    func cancelRecording() {
        stopMonitor()
        isRecording = false
        message = nil
        isRegistered = register(keyCode, modifiers)
    }

    func reset() {
        if isRecording { stopMonitor(); isRecording = false }
        for k in ["hotKeyCode", "hotKeyModifiers", "hotKeyName"] { defaults.removeObject(forKey: k) }
        isRegistered = register(keyCode, modifiers)
        display = Self.describe(modifiers, keyName)
        message = isRegistered ? nil : "⌃⌘V başka bir uygulama tarafından kullanılıyor."
        objectWillChange.send()
    }

    private func handle(_ e: NSEvent) {
        if e.keyCode == UInt16(kVK_Escape) { cancelRecording(); return }

        let f = e.modifierFlags.intersection(.deviceIndependentFlagsMask)
        var mods: UInt32 = 0
        if f.contains(.command) { mods |= UInt32(cmdKey) }
        if f.contains(.option) { mods |= UInt32(optionKey) }
        if f.contains(.control) { mods |= UInt32(controlKey) }
        if f.contains(.shift) { mods |= UInt32(shiftKey) }
        guard mods & UInt32(cmdKey | optionKey | controlKey) != 0 else {
            message = "En az bir tane ⌘, ⌥ veya ⌃ tuşu içermeli."
            NSSound.beep()
            return
        }

        let code = UInt32(e.keyCode)
        let name = Self.keyName(for: e)
        guard register(code, mods) else {
            message = "\(Self.describe(mods, name)) başka bir uygulama tarafından kullanılıyor."
            NSSound.beep()
            return
        }
        defaults.set(Int(code), forKey: "hotKeyCode")
        defaults.set(Int(mods), forKey: "hotKeyModifiers")
        defaults.set(name, forKey: "hotKeyName")
        stopMonitor()
        isRecording = false
        isRegistered = true
        message = nil
        display = Self.describe(mods, name)
    }

    private func stopMonitor() {
        if let m = monitor { NSEvent.removeMonitor(m); monitor = nil }
    }

    // MARK: Carbon

    private func register(_ code: UInt32, _ mods: UInt32) -> Bool {
        unregister()
        let id = EventHotKeyID(signature: OSType(0x50414E4F), id: 1) // "PANO"
        return RegisterEventHotKey(code, mods, id, GetApplicationEventTarget(), 0, &ref) == noErr
    }

    private func unregister() {
        if let r = ref { UnregisterEventHotKey(r); ref = nil }
    }

    // MARK: Yazıya çevirme

    static func describe(_ m: UInt32, _ key: String) -> String {
        var s = ""
        if m & UInt32(controlKey) != 0 { s += "⌃" }
        if m & UInt32(optionKey) != 0 { s += "⌥" }
        if m & UInt32(shiftKey) != 0 { s += "⇧" }
        if m & UInt32(cmdKey) != 0 { s += "⌘" }
        return s + key
    }

    private static func keyName(for e: NSEvent) -> String {
        switch Int(e.keyCode) {
        case kVK_Space: return "Space"
        case kVK_Return: return "↩"
        case kVK_Tab: return "⇥"
        case kVK_Delete: return "⌫"
        case kVK_LeftArrow: return "←"
        case kVK_RightArrow: return "→"
        case kVK_UpArrow: return "↑"
        case kVK_DownArrow: return "↓"
        default: break
        }
        if let sp = e.specialKey,
           let i = [NSEvent.SpecialKey.f1, .f2, .f3, .f4, .f5, .f6, .f7, .f8, .f9, .f10, .f11, .f12].firstIndex(of: sp) {
            return "F\(i + 1)"
        }
        return (e.charactersIgnoringModifiers ?? "?").uppercased()
    }
}
