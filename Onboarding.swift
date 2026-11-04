import Cocoa
import SwiftUI
import ServiceManagement

// MARK: - Model

final class OnboardingModel: ObservableObject {
    @Published var axTrusted = AXIsProcessTrusted()
    @Published var launchAtLogin = true
    @Published var triedShortcut = false
    @Published var shortcut = "⌃⌘V"
    var onFinish: (() -> Void)?

    private var timer: Timer?

    func startWatching() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self else { return }
            let now = AXIsProcessTrusted()
            if now && !self.axTrusted {
                // İzin verildi: pencereyi Sistem Ayarları'nın önüne getir
                NSApp.activate(ignoringOtherApps: true)
            }
            self.axTrusted = now
        }
    }

    func stopWatching() { timer?.invalidate(); timer = nil }
}

// MARK: - Pencere

final class OnboardingWindowController: NSObject, NSWindowDelegate {
    let model = OnboardingModel()
    private var window: NSWindow?

    var isVisible: Bool { window?.isVisible == true }

    func show(shortcut: String) {
        model.shortcut = shortcut
        model.axTrusted = AXIsProcessTrusted()
        model.onFinish = { [weak self] in self?.finish() }
        if window == nil {
            let host = NSHostingController(rootView: OnboardingView(model: model))
            let w = NSWindow(contentViewController: host)
            w.styleMask = [.titled, .closable, .fullSizeContentView]
            w.titlebarAppearsTransparent = true
            w.titleVisibility = .hidden
            w.isMovableByWindowBackground = true
            w.isReleasedWhenClosed = false
            w.delegate = self
            w.center()
            window = w
        }
        model.startWatching()
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    /// Kısayola basıldığında çağrılır ("dene" adımı için)
    func shortcutPressed() {
        if isVisible { model.triedShortcut = true }
    }

    private func finish() {
        let on = model.launchAtLogin
        do {
            if on && SMAppService.mainApp.status != .enabled { try SMAppService.mainApp.register() }
            if !on && SMAppService.mainApp.status == .enabled { try SMAppService.mainApp.unregister() }
        } catch {}
        UserDefaults.standard.set(true, forKey: "onboarded")
        window?.close()
    }

    func windowWillClose(_ notification: Notification) {
        model.stopWatching()
        UserDefaults.standard.set(true, forKey: "onboarded")
    }
}

// MARK: - Görünüm

struct OnboardingView: View {
    @ObservedObject var model: OnboardingModel

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 84, height: 84)
                Text("Pano Geçmişi'ne hoş geldin")
                    .font(.system(size: 22, weight: .semibold))
                Text("Kopyaladıklarını saklar, \(model.shortcut) ile istediğin yere yapıştırırsın.\nKurulum yarım dakika sürer.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 36)
            .padding(.bottom, 24)

            VStack(spacing: 10) {
                StepCard(number: 1, done: model.axTrusted,
                         title: "Direkt yapıştırma izni",
                         detail: model.axTrusted
                            ? "İzin verildi."
                            : "Açılan pencerede “Pano Geçmişi”nin yanındaki anahtarı aç. Parolanı isteyebilir.") {
                    if !model.axTrusted {
                        Button("İzni Aç") { requestAccessibility() }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                    }
                }

                StepCard(number: 2, done: model.launchAtLogin, neutral: !model.launchAtLogin,
                         title: "Mac açılınca otomatik başlasın",
                         detail: "Her seferinde açmana gerek kalmaz. Ekranın üstünde küçük bir simge olarak durur.") {
                    Toggle("", isOn: $model.launchAtLogin)
                        .toggleStyle(.switch)
                        .labelsHidden()
                }

                StepCard(number: 3, done: model.triedShortcut,
                         title: model.triedShortcut ? "Harika, çalışıyor!" : "Bir dene",
                         detail: model.triedShortcut
                            ? "Artık istediğin yerde \(model.shortcut) ile geçmişini açabilirsin."
                            : "Bir şey kopyala, sonra şu tuşlara birlikte bas:") {
                    if !model.triedShortcut {
                        HStack(spacing: 4) {
                            ForEach(keys, id: \.self) { BigKey($0) }
                        }
                    }
                }
            }
            .padding(.horizontal, 28)

            Spacer(minLength: 20)

            HStack {
                Text("Bedirhan Aydın")
                    .font(.custom("Snell Roundhand", size: 15))
                    .foregroundStyle(.tertiary)
                Spacer()
                if !model.axTrusted {
                    Button("Şimdilik geç") { model.onFinish?() }
                        .buttonStyle(.link)
                        .padding(.trailing, 8)
                }
                Button("Başla") { model.onFinish?() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!model.axTrusted)
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 24)
        }
        .frame(width: 540, height: 600)
    }

    /// "⌃⌘V" → ["⌃", "⌘", "V"]
    private var keys: [String] {
        let mods = Set("⌃⌥⇧⌘")
        var out: [String] = []
        var rest = ""
        for ch in model.shortcut {
            if mods.contains(ch) && rest.isEmpty { out.append(String(ch)) } else { rest.append(ch) }
        }
        if !rest.isEmpty { out.append(rest) }
        return out
    }
}

struct StepCard<Accessory: View>: View {
    let number: Int
    let done: Bool
    var neutral = false
    let title: String
    let detail: String
    @ViewBuilder let accessory: Accessory

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(done ? Color.green : Color.primary.opacity(neutral ? 0.08 : 0.10))
                    .frame(width: 30, height: 30)
                if done {
                    Image(systemName: "checkmark").font(.system(size: 13, weight: .bold)).foregroundStyle(.white)
                } else {
                    Text("\(number)").font(.system(size: 13, weight: .semibold)).foregroundStyle(.secondary)
                }
            }
            .animation(.spring(duration: 0.3), value: done)

            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 14, weight: .semibold))
                Text(detail).font(.system(size: 12)).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            accessory
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(Color.primary.opacity(0.045)))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .strokeBorder(done ? Color.green.opacity(0.35) : Color.primary.opacity(0.06), lineWidth: 1))
    }
}

struct BigKey: View {
    let text: String
    init(_ t: String) { text = t }

    var body: some View {
        Text(text)
            .font(.system(size: 15, weight: .semibold, design: .rounded))
            .frame(minWidth: 32, minHeight: 32)
            .padding(.horizontal, 4)
            .background(RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
                .shadow(color: .black.opacity(0.18), radius: 0, y: 1.5))
            .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.15), lineWidth: 0.5))
    }
}
