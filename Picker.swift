import Cocoa
import SwiftUI
import Carbon

// MARK: - Model

enum PickerTab: CaseIterable {
    case recent, pinned
    var title: String { self == .recent ? "Son kopyalananlar" : "Sık kullanılanlar" }
    var symbol: String { self == .recent ? "clock" : "star.fill" }
}

struct PickerRow: Identifiable {
    let id: Int        // listedeki konumu
    let clip: Clip
}

/// Arama kutusundaki "safari: kelime" ya da "resim:" gibi süzgeçler
struct SearchFilter {
    var appName: String?
    var bundleID: String?
    var onlyImages = false
    var text: String

    var hasScope: Bool { bundleID != nil || onlyImages }

    static func parse(_ query: String, clips: [Clip]) -> SearchFilter {
        guard let colon = query.firstIndex(of: ":") else { return SearchFilter(text: query) }
        let prefix = fold(String(query[..<colon]))
        let rest = String(query[query.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
        guard !prefix.isEmpty, !prefix.contains(" ") else { return SearchFilter(text: query) }

        if prefix.count >= 2, ["resim", "gorsel", "foto"].contains(where: { $0.hasPrefix(prefix) }) {
            return SearchFilter(onlyImages: true, text: rest)
        }
        if let c = clips.first(where: { fold($0.appName ?? "").hasPrefix(prefix) }) {
            return SearchFilter(appName: c.appName, bundleID: c.appBundleID, text: rest)
        }
        return SearchFilter(text: query)   // "http:" gibi normal bir arama
    }

    func matches(_ c: Clip) -> Bool {
        if onlyImages && !c.isImage { return false }
        if let b = bundleID, c.appBundleID != b { return false }
        if text.isEmpty { return true }
        if c.isImage { return false }
        return c.text.range(of: text, options: [.caseInsensitive, .diacriticInsensitive]) != nil
    }
}

final class PickerModel: ObservableObject {
    @Published var tab: PickerTab = .recent { didSet { selected = 0 } }
    @Published var query = "" { didSet { selected = 0 } }
    @Published var selected = 0
    @Published var shortcut = "⌃⌘V"
    /// Sadece önizleme görüntüsü üretirken: kaydırma ve cam efekti yerine düz çizim
    var staticLayout = false

    func source(_ store: ClipStore) -> [Clip] { tab == .recent ? store.recent : store.pinned }

    func filter(_ store: ClipStore) -> SearchFilter { SearchFilter.parse(query, clips: store.clips) }

    func rows(_ store: ClipStore) -> [PickerRow] {
        let f = filter(store)
        return source(store).filter(f.matches).enumerated().map { PickerRow(id: $0.offset, clip: $0.element) }
    }
}

// MARK: - Ana görünüm

struct PickerView: View {
    @ObservedObject var model: PickerModel
    @ObservedObject var store: ClipStore
    let onPick: (UUID) -> Void

    var body: some View {
        let rows = model.rows(store)
        let filter = model.filter(store)
        let sourceCount = model.source(store).count

        VStack(spacing: 0) {
            SearchBar(query: model.query, filter: filter)
            TabBar(model: model, recentCount: store.recent.count, pinnedCount: store.pinned.count)
            Divider().opacity(0.5)

            Group {
                if sourceCount == 0 {
                    if model.tab == .recent {
                        EmptyState(symbol: "list.clipboard", title: "Henüz bir şey kopyalanmadı",
                                   subtitle: "Bir şey kopyala (⌘C), sonra \(model.shortcut) ile buradan yapıştır.")
                    } else {
                        EmptyState(symbol: "star", title: "Henüz sık kullanılan yok",
                                   subtitle: "Son kopyalananlarda bir kaydı seç ve ⌘P ile buraya sabitle.\nSabitlenenler hiç silinmez.")
                    }
                } else if rows.isEmpty {
                    EmptyState(symbol: "magnifyingglass", title: "Sonuç yok",
                               subtitle: "Başka bir kelime dene ya da esc ile aramayı temizle.")
                } else {
                    HStack(spacing: 0) {
                        list(rows, filter: filter).frame(width: 360)
                        Divider().opacity(0.5)
                        DetailPane(clip: rows[min(model.selected, rows.count - 1)].clip, query: filter.text)
                    }
                }
            }
            .frame(maxHeight: .infinity)

            Divider().opacity(0.5)
            Footer(tab: model.tab)
        }
        .frame(width: 720, height: 470)
        .modifier(PanelBackground(staticLayout: model.staticLayout))
    }

    @ViewBuilder
    private func list(_ rows: [PickerRow], filter: SearchFilter) -> some View {
        let content = VStack(spacing: 2) {
            ForEach(rows) { row in
                ClipRow(row: row, query: filter.text, isSelected: row.id == model.selected)
                    .id(row.id)
                    .contentShape(Rectangle())
                    .onHover { if $0 { model.selected = row.id } }
                    .onTapGesture { onPick(row.clip.id) }
            }
        }
        .padding(8)

        if model.staticLayout {
            VStack(spacing: 0) { content; Spacer(minLength: 0) }
        } else {
            ScrollViewReader { proxy in
                ScrollView { content }
                    .onChange(of: model.selected) { _, v in
                        withAnimation(.easeOut(duration: 0.12)) { proxy.scrollTo(v) }
                    }
            }
        }
    }
}

// MARK: - Parçalar

struct SearchBar: View {
    let query: String
    let filter: SearchFilter

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.secondary)

            if filter.hasScope {
                HStack(spacing: 5) {
                    if filter.onlyImages {
                        Image(systemName: "photo").font(.system(size: 11, weight: .semibold))
                        Text("Resimler")
                    } else {
                        if let i = AppIcons.icon(for: filter.bundleID) {
                            Image(nsImage: i).resizable().frame(width: 16, height: 16)
                        }
                        Text(filter.appName ?? "")
                    }
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(Capsule().fill(Color.accentColor.opacity(0.14)))
            }

            let shown = filter.hasScope ? filter.text : query
            HStack(spacing: 1) {
                if shown.isEmpty {
                    if !filter.hasScope {
                        Text("Geçmişte ara…").foregroundStyle(.tertiary)
                    }
                    Rectangle().fill(Color.accentColor).frame(width: 2, height: 20)
                        .opacity(filter.hasScope ? 1 : 0)
                } else {
                    Text(shown)
                    Rectangle().fill(Color.accentColor).frame(width: 2, height: 20)
                }
            }
            .font(.system(size: 18))
            .lineLimit(1)

            Spacer()

            if query.isEmpty {
                Text("uygulamaya göre:  safari:   ·   resim:")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 52)
    }
}

struct TabBar: View {
    @ObservedObject var model: PickerModel
    let recentCount: Int
    let pinnedCount: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(PickerTab.allCases, id: \.self) { tab in
                let on = model.tab == tab
                HStack(spacing: 6) {
                    Image(systemName: tab.symbol)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(tab == .pinned ? Color.yellow : Color.secondary)
                    Text(tab.title)
                    Text("\(tab == .recent ? recentCount : pinnedCount)")
                        .font(.system(size: 11, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                .font(.system(size: 12.5, weight: on ? .semibold : .regular))
                .foregroundStyle(on ? Color.primary : Color.secondary)
                .padding(.horizontal, 12)
                .frame(height: 28)
                .background(Capsule().fill(on ? Color.primary.opacity(0.10) : Color.clear))
                .contentShape(Capsule())
                .onTapGesture { model.tab = tab }
            }
            Spacer()
            Keycap("⇥")
            Text("sekme değiştir").font(.system(size: 11)).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }
}

struct ClipRow: View {
    let row: PickerRow
    let query: String
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            if row.clip.isImage {
                Thumbnail(clip: row.clip, size: 22)
            } else {
                SourceIcon(clip: row.clip, size: 22, onAccent: isSelected)
            }
            Text(highlight(row.clip.preview, query: query, onAccent: isSelected))
                .font(.system(size: 13))
                .lineLimit(1)
                .truncationMode(.tail)
                .foregroundStyle(isSelected ? Color.white : Color.primary)
            Spacer(minLength: 6)
            Text(TimeText.short(row.clip.date))
                .font(.system(size: 11))
                .monospacedDigit()
                .foregroundStyle(isSelected ? Color.white.opacity(0.75) : Color.secondary)
            if row.id < 9 {
                Keycap("⌘\(row.id + 1)", onAccent: isSelected)
            } else {
                Color.clear.frame(width: 26, height: 1)
            }
        }
        .padding(.horizontal, 8)
        .frame(height: 36)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(isSelected ? Color.accentColor : Color.clear))
    }
}

struct Thumbnail: View {
    let clip: Clip
    let size: CGFloat

    var body: some View {
        Group {
            if let img = ClipImages.image(for: clip) {
                Image(nsImage: img).resizable().aspectRatio(contentMode: .fill)
            } else {
                Image(systemName: "photo").foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
            .strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.5))
    }
}

struct DetailPane: View {
    let clip: Clip
    let query: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Chip(symbol: clip.kind.symbol, text: clip.kind.title, color: .accentColor)
                if clip.isPinned { Chip(symbol: "star.fill", text: "Sık kullanılan", color: .orange) }
            }
            .padding([.top, .horizontal], 16)

            Group {
                if clip.isImage {
                    if let img = ClipImages.image(for: clip) {
                        Image(nsImage: img)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .shadow(color: .black.opacity(0.15), radius: 6, y: 2)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        EmptyState(symbol: "photo", title: "Resim bulunamadı", subtitle: "")
                    }
                } else {
                    Text(highlight(String(clip.text.prefix(3000)), query: query, onAccent: false))
                        .font(clip.kind == .multiline ? .system(size: 12.5, design: .monospaced) : .system(size: 14))
                        .lineSpacing(3)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
            }
            .padding(16)
            .clipped()

            Divider().opacity(0.5)

            VStack(alignment: .leading, spacing: 8) {
                InfoRow(label: "Kaynak") {
                    HStack(spacing: 6) {
                        if AppIcons.icon(for: clip.appBundleID) != nil {
                            SourceIcon(clip: clip, size: 16, onAccent: false)
                        }
                        Text(clip.appName ?? "Bilinmiyor")
                    }
                }
                InfoRow(label: "Kopyalandı") {
                    Text("\(TimeText.long(clip.date))  ·  \(TimeText.exactText(clip.date))")
                }
                InfoRow(label: "Boyut") { Text(clip.sizeText) }
            }
            .padding(16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct Chip: View {
    let symbol: String
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: symbol)
            Text(text)
        }
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(color)
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(Capsule().fill(color.opacity(0.13)))
    }
}

struct InfoRow<Content: View>: View {
    let label: String
    @ViewBuilder let content: Content

    var body: some View {
        HStack(spacing: 0) {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .leading)
            content
            Spacer(minLength: 0)
        }
        .font(.system(size: 11.5))
        .lineLimit(1)
    }
}

struct SourceIcon: View {
    let clip: Clip
    let size: CGFloat
    let onAccent: Bool

    var body: some View {
        if let icon = AppIcons.icon(for: clip.appBundleID) {
            Image(nsImage: icon)
                .resizable()
                .interpolation(.high)
                .frame(width: size, height: size)
        } else {
            Image(systemName: clip.kind.symbol)
                .font(.system(size: size * 0.5, weight: .semibold))
                .foregroundStyle(onAccent ? Color.white : Color.secondary)
                .frame(width: size, height: size)
                .background(RoundedRectangle(cornerRadius: size * 0.25, style: .continuous)
                    .fill(onAccent ? Color.white.opacity(0.2) : Color.primary.opacity(0.08)))
        }
    }
}

struct Keycap: View {
    let text: String
    let onAccent: Bool
    init(_ text: String, onAccent: Bool = false) { self.text = text; self.onAccent = onAccent }

    var body: some View {
        Text(text)
            .font(.system(size: 10.5, weight: .semibold, design: .rounded))
            .foregroundStyle(onAccent ? Color.white : Color.secondary)
            .padding(.horizontal, 5)
            .frame(minWidth: 20, minHeight: 18)
            .background(RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(onAccent ? Color.white.opacity(0.22) : Color.primary.opacity(0.07)))
            .overlay(RoundedRectangle(cornerRadius: 5, style: .continuous)
                .strokeBorder(onAccent ? Color.white.opacity(0.25) : Color.primary.opacity(0.10), lineWidth: 0.5))
    }
}

struct Footer: View {
    let tab: PickerTab

    var body: some View {
        HStack(spacing: 14) {
            hint(["↑", "↓"], "gezin")
            hint(["↩"], "yapıştır")
            hint(["⌘P"], tab == .recent ? "sabitle" : "kaldır")
            hint(["⌘⌫"], "sil")
            Spacer()
            Text("Bedirhan Aydın")
                .font(.custom("Snell Roundhand", size: 14))
                .foregroundStyle(.tertiary)
            hint(["esc"], "kapat")
        }
        .padding(.horizontal, 16)
        .frame(height: 36)
    }

    private func hint(_ keys: [String], _ label: String) -> some View {
        HStack(spacing: 4) {
            ForEach(keys, id: \.self) { Keycap($0) }
            Text(label).font(.system(size: 11)).foregroundStyle(.secondary)
        }
    }
}

struct EmptyState: View {
    let symbol: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(.tertiary)
            Text(title).font(.system(size: 15, weight: .semibold))
            if !subtitle.isEmpty {
                Text(subtitle).font(.system(size: 12.5)).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(30)
    }
}

/// macOS 26+: Liquid Glass. Daha eski sürümlerde bulanık cam zemin.
struct PanelBackground: ViewModifier {
    let staticLayout: Bool

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: 24, style: .continuous)
        if staticLayout {
            content.background(Color(nsColor: .windowBackgroundColor)).clipShape(shape)
        } else if #available(macOS 26.0, *) {
            content
                .clipShape(shape)
                .glassEffect(.regular, in: shape)
        } else {
            content
                .background(VisualEffect())
                .clipShape(shape)
                .overlay(shape.strokeBorder(Color.primary.opacity(0.10), lineWidth: 1))
        }
    }
}

/// Pencere arkasını bulanıklaştıran macOS cam efekti (eski sürümler için)
struct VisualEffect: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = .popover
        v.blendingMode = .behindWindow
        v.state = .active
        return v
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

/// Aranan kelimeyi metin içinde vurgular
func highlight(_ text: String, query: String, onAccent: Bool) -> AttributedString {
    var attr = AttributedString(text)
    guard !query.isEmpty else { return attr }
    var searchStart = text.startIndex
    while let r = text.range(of: query, options: [.caseInsensitive, .diacriticInsensitive], range: searchStart..<text.endIndex) {
        if let ar = Range(r, in: attr) {
            attr[ar].inlinePresentationIntent = .stronglyEmphasized
            if onAccent {
                attr[ar].underlineStyle = .single
            } else {
                attr[ar].backgroundColor = Color.yellow.opacity(0.35)
            }
        }
        searchStart = r.upperBound
    }
    return attr
}

// MARK: - Pencere

/// Başka uygulamadan odağı çalmayan, ama klavyeyi alabilen panel
final class PickerPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

final class PickerController {
    let model = PickerModel()
    let store: ClipStore
    var onPick: ((UUID) -> Void)?

    init(store: ClipStore) { self.store = store }

    private lazy var panel: PickerPanel = {
        let p = PickerPanel(contentRect: NSRect(x: 0, y: 0, width: 720, height: 470),
                            styleMask: [.nonactivatingPanel, .borderless],
                            backing: .buffered, defer: false)
        p.isFloatingPanel = true
        p.level = .popUpMenu
        p.backgroundColor = .clear
        p.isOpaque = false
        p.hasShadow = true
        p.hidesOnDeactivate = false
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        p.contentView = NSHostingView(rootView: PickerView(model: model, store: store) { [weak self] id in
            self?.pick(id)
        })
        NotificationCenter.default.addObserver(forName: NSWindow.didResignKeyNotification,
                                               object: p, queue: .main) { [weak self] _ in self?.hide() }
        return p
    }()

    private var monitor: Any?

    var isVisible: Bool { panel.isVisible }

    func toggle(shortcut: String) {
        isVisible ? hide() : show(shortcut: shortcut)
    }

    func show(shortcut: String) {
        model.shortcut = shortcut
        model.query = ""
        model.tab = .recent
        model.selected = 0
        panel.setFrameOrigin(origin(for: panel.frame.size))
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        panel.makeKey()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.12
            panel.animator().alphaValue = 1
        }

        if monitor == nil {
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] e in
                guard let self, self.panel.isKeyWindow else { return e }
                return self.handle(e) ? nil : e
            }
        }
    }

    func hide() {
        guard panel.isVisible else { return }
        panel.orderOut(nil)
        if let m = monitor { NSEvent.removeMonitor(m); monitor = nil }
    }

    private func pick(_ id: UUID) {
        hide()
        onPick?(id)
    }

    private func clampSelection() {
        let n = model.rows(store).count
        model.selected = min(model.selected, max(n - 1, 0))
    }

    private func handle(_ e: NSEvent) -> Bool {
        let rows = model.rows(store)
        let flags = e.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let current = model.selected < rows.count ? rows[model.selected].clip : nil

        switch Int(e.keyCode) {
        case kVK_Escape:
            if model.query.isEmpty { hide() } else { model.query = "" }
            return true
        case kVK_Return, kVK_ANSI_KeypadEnter:
            if let c = current { pick(c.id) }
            return true
        case kVK_Tab:
            model.tab = model.tab == .recent ? .pinned : .recent
            return true
        case kVK_DownArrow:
            if !rows.isEmpty { model.selected = min(model.selected + 1, rows.count - 1) }
            return true
        case kVK_UpArrow:
            model.selected = max(model.selected - 1, 0); return true
        case kVK_Delete where flags.contains(.command):
            if let c = current { store.delete(c.id); clampSelection() }
            return true
        case kVK_Delete:
            if !model.query.isEmpty { model.query.removeLast() }
            return true
        case kVK_ANSI_P where flags.contains(.command):
            if let c = current { store.togglePin(c.id); clampSelection() }
            return true
        default: break
        }

        if flags.contains(.command) {
            if let ch = e.charactersIgnoringModifiers, let n = Int(ch), (1...9).contains(n), n <= rows.count {
                pick(rows[n - 1].clip.id)
            }
            return true
        }
        if flags.contains(.control) { return true }

        if let chars = e.characters, !chars.isEmpty,
           chars.unicodeScalars.allSatisfy({ !CharacterSet.controlCharacters.contains($0) }) {
            model.query += chars
        }
        return true
    }

    // MARK: Konum: önce yazı imlecinin altı, olmazsa fare

    private func origin(for size: NSSize) -> NSPoint {
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        let caret = caretRect()
        var top: NSPoint
        if let caret {
            top = NSPoint(x: caret.minX - 20, y: primaryHeight - caret.maxY - 6)
        } else {
            let m = NSEvent.mouseLocation
            top = NSPoint(x: m.x - 20, y: m.y - 6)
        }

        let screen = NSScreen.screens.first { $0.frame.contains(top) } ?? NSScreen.main
        let vf = screen?.visibleFrame ?? .zero
        var o = NSPoint(x: top.x, y: top.y - size.height)
        if o.y < vf.minY {          // altta yer yoksa imlecin üstüne aç
            o.y = caret.map { primaryHeight - $0.minY + 6 } ?? top.y + 12
        }
        o.x = min(max(o.x, vf.minX + 8), vf.maxX - size.width - 8)
        o.y = min(max(o.y, vf.minY + 8), vf.maxY - size.height - 8)
        return o
    }

    private func caretRect() -> CGRect? {
        guard AXIsProcessTrusted() else { return nil }
        let system = AXUIElementCreateSystemWide()
        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(system, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
              let f = focused, CFGetTypeID(f) == AXUIElementGetTypeID() else { return nil }
        let element = f as! AXUIElement

        var range: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &range) == .success,
              let r = range else { return nil }

        var bounds: CFTypeRef?
        guard AXUIElementCopyParameterizedAttributeValue(element, kAXBoundsForRangeParameterizedAttribute as CFString,
                                                         r, &bounds) == .success,
              let b = bounds, CFGetTypeID(b) == AXValueGetTypeID() else { return nil }

        var rect = CGRect.zero
        guard AXValueGetValue(b as! AXValue, .cgRect, &rect), rect.height > 0,
              rect.origin != .zero else { return nil }
        return rect
    }
}
