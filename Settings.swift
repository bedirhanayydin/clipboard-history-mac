import Cocoa
import SwiftUI
import ServiceManagement
import UniformTypeIdentifiers

// MARK: - Pencere

final class SettingsWindowController {
    private var window: NSWindow?
    private let store: ClipStore
    private let hotkeys: HotKeyManager

    init(store: ClipStore, hotkeys: HotKeyManager) {
        self.store = store
        self.hotkeys = hotkeys
    }

    func show() {
        if window == nil {
            let host = NSHostingController(rootView: SettingsView(store: store, hotkeys: hotkeys))
            let w = NSWindow(contentViewController: host)
            w.title = "Pano Geçmişi Ayarları"
            w.styleMask = [.titled, .closable]
            w.isReleasedWhenClosed = false
            w.center()
            window = w
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

// MARK: - Görünüm

struct SettingsView: View {
    @ObservedObject var store: ClipStore
    @ObservedObject var hotkeys: HotKeyManager

    var body: some View {
        TabView {
            GeneralTab(store: store, hotkeys: hotkeys)
                .tabItem { Label("Genel", systemImage: "gearshape") }
            ExcludedTab(store: store)
                .tabItem { Label("Hariç Tutulanlar", systemImage: "hand.raised") }
            AboutTab()
                .tabItem { Label("Hakkında", systemImage: "info.circle") }
        }
        .frame(width: 540, height: 470)
    }
}

struct GeneralTab: View {
    @ObservedObject var store: ClipStore
    @ObservedObject var hotkeys: HotKeyManager
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginError: String?
    @State private var axTrusted = AXIsProcessTrusted()
    @State private var confirmClear = false

    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        Form {
            Section("Kısayol") {
                LabeledContent("Geçmişi aç") {
                    HStack(spacing: 8) {
                        if hotkeys.isCustom && !hotkeys.isRecording {
                            Button("Varsayılan (⌃⌘V)") { hotkeys.reset() }
                                .buttonStyle(.link)
                                .font(.system(size: 12))
                        }
                        Button {
                            hotkeys.isRecording ? hotkeys.cancelRecording() : hotkeys.startRecording()
                        } label: {
                            Text(hotkeys.isRecording ? "Yeni kısayola bas…" : hotkeys.display)
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .frame(minWidth: 110)
                        }
                        .controlSize(.large)
                        .tint(hotkeys.isRecording ? .accentColor : nil)
                        .buttonStyle(.bordered)
                    }
                }
                if let m = hotkeys.message {
                    Label(m, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.system(size: 12))
                } else if hotkeys.isRecording {
                    Text("Değiştirmek için yeni kombinasyona bas. Vazgeçmek için esc.")
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                }
            }

            Section {
                Picker("Saklanacak kayıt", selection: $store.limit) {
                    ForEach(ClipStore.limitOptions, id: \.self) { Text("Son \($0)").tag($0) }
                }
                .pickerStyle(.segmented)
                HStack {
                    Text("\(store.recent.count) son kopyalanan  ·  \(store.pinned.count) sık kullanılan")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Son kopyalananları temizle", role: .destructive) { confirmClear = true }
                        .disabled(store.recent.isEmpty)
                }
            } header: {
                Text("Geçmiş")
            } footer: {
                Text("Sık kullanılanlar bu sınıra dahil değildir ve sen kaldırana kadar silinmez.")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }

            Section("Sistem") {
                Toggle("Mac açılınca otomatik başlat", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, on in setLogin(on) }
                if let e = loginError {
                    Text(e).font(.system(size: 11)).foregroundStyle(.orange)
                }
                LabeledContent("Direkt yapıştırma izni") {
                    if axTrusted {
                        Label("Verildi", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                    } else {
                        Button("İzin ver…") { requestAccessibility() }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .onReceive(tick) { _ in axTrusted = AXIsProcessTrusted() }
        .confirmationDialog("Son kopyalananlar silinsin mi?", isPresented: $confirmClear) {
            Button("Temizle", role: .destructive) { store.clearRecent() }
        } message: {
            Text("Sık kullanılanlar silinmez.")
        }
    }

    private func setLogin(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            loginError = nil
        } catch {
            loginError = "Ayarlanamadı. Uygulamanın Uygulamalar klasöründe olduğundan emin ol."
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}

struct ExcludedTab: View {
    @ObservedObject var store: ClipStore
    @State private var selection: String?

    private var runningApps: [NSRunningApplication] {
        NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && $0.bundleIdentifier != nil
                && $0.bundleIdentifier != Bundle.main.bundleIdentifier
                && !store.isExcluded($0.bundleIdentifier) }
            .sorted { ($0.localizedName ?? "") < ($1.localizedName ?? "") }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Bu uygulamalardan kopyaladıkların geçmişe kaydedilmez. Bankacılık, şifre ya da gizli bilgi içeren uygulamalar için kullan.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            List(selection: $selection) {
                ForEach(store.excluded) { app in
                    HStack(spacing: 10) {
                        if let i = AppIcons.icon(for: app.bundleID) {
                            Image(nsImage: i).resizable().frame(width: 22, height: 22)
                        } else {
                            Image(systemName: "app.dashed").frame(width: 22, height: 22).foregroundStyle(.secondary)
                        }
                        Text(app.name)
                        Spacer()
                        Button {
                            store.excluded.removeAll { $0.bundleID == app.bundleID }
                        } label: {
                            Image(systemName: "minus.circle.fill").foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("Listeden çıkar")
                    }
                    .padding(.vertical, 2)
                    .tag(app.bundleID)
                }
            }
            .listStyle(.bordered(alternatesRowBackgrounds: true))
            .overlay {
                if store.excluded.isEmpty {
                    Text("Hariç tutulan uygulama yok").foregroundStyle(.secondary)
                }
            }

            HStack {
                Menu {
                    ForEach(runningApps, id: \.processIdentifier) { app in
                        Button {
                            add(app.bundleIdentifier, app.localizedName)
                        } label: {
                            if let i = app.icon {
                                Image(nsImage: resized(i, 16))
                            }
                            Text(app.localizedName ?? app.bundleIdentifier ?? "")
                        }
                    }
                } label: {
                    Label("Açık uygulamalardan ekle", systemImage: "plus")
                }
                .fixedSize()

                Button("Uygulama seç…") { chooseApp() }
                Spacer()
            }

            Label("Şifre yöneticilerinden kopyalanan şifreler zaten hiç kaydedilmez.", systemImage: "lock.fill")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .padding(20)
    }

    private func add(_ bundleID: String?, _ name: String?) {
        guard let id = bundleID, !store.isExcluded(id) else { return }
        store.excluded.append(ExcludedApp(bundleID: id, name: name ?? id))
    }

    private func chooseApp() {
        let p = NSOpenPanel()
        p.allowedContentTypes = [.application]
        p.directoryURL = URL(fileURLWithPath: "/Applications")
        p.allowsMultipleSelection = true
        p.prompt = "Hariç Tut"
        guard p.runModal() == .OK else { return }
        for url in p.urls {
            let b = Bundle(url: url)
            let name = (b?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
                ?? FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
            add(b?.bundleIdentifier, name)
        }
    }

    private func resized(_ img: NSImage, _ s: CGFloat) -> NSImage {
        let r = NSImage(size: NSSize(width: s, height: s))
        r.lockFocus()
        img.draw(in: NSRect(x: 0, y: 0, width: s, height: s))
        r.unlockFocus()
        return r
    }
}

struct AboutTab: View {
    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "–"
    }

    var body: some View {
        VStack(spacing: 10) {
            Spacer()
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)
            Text("Pano Geçmişi").font(.system(size: 20, weight: .semibold))
            Text("Sürüm \(version)").font(.system(size: 12)).foregroundStyle(.secondary)
            Text("Bedirhan Aydın")
                .font(.custom("Snell Roundhand", size: 26))
                .foregroundStyle(.secondary)
                .padding(.top, 6)
            Spacer()
            Label("Kopyaladıkların sadece bu Mac'te saklanır, hiçbir yere gönderilmez.", systemImage: "lock.shield")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity)
    }
}

func requestAccessibility() {
    let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
    _ = AXIsProcessTrustedWithOptions(opts)
    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
        NSWorkspace.shared.open(url)
    }
}
