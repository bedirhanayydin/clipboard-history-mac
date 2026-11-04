import Cocoa
import CryptoKit

/// Kopyalanmaması (kaydedilmemesi) istenen uygulama
struct ExcludedApp: Codable, Hashable, Identifiable {
    var bundleID: String
    var name: String
    var id: String { bundleID }
}

/// Tüm kayıtları ve geçmişle ilgili ayarları tutar, diske yazar
final class ClipStore: ObservableObject {
    @Published private(set) var clips: [Clip] = []

    @Published var limit: Int {
        didSet { if persist { defaults.set(limit, forKey: "limit") }; trim(); save() }
    }

    @Published var excluded: [ExcludedApp] {
        didSet {
            if persist, let d = try? JSONEncoder().encode(excluded) { defaults.set(d, forKey: "excludedApps") }
        }
    }

    private let defaults = UserDefaults.standard
    private let persist: Bool

    static let limitOptions = [10, 20]

    init() {
        persist = true
        let l = defaults.integer(forKey: "limit")
        limit = Self.limitOptions.contains(l) ? l : 10
        if let d = defaults.data(forKey: "excludedApps"),
           let list = try? JSONDecoder().decode([ExcludedApp].self, from: d) {
            excluded = list
        } else {
            excluded = [ExcludedApp(bundleID: "com.apple.keychainaccess", name: "Anahtar Zinciri Erişimi"),
                        ExcludedApp(bundleID: "com.apple.Passwords", name: "Parolalar")]
        }
        load()
    }

    /// Sadece önizleme görüntüsü üretmek için: diske dokunmaz
    init(preview: [Clip]) {
        persist = false
        limit = 10
        excluded = []
        clips = preview
    }

    // MARK: Listeler

    var recent: [Clip] { clips.filter { !$0.isPinned }.sorted { $0.date > $1.date } }
    var pinned: [Clip] { clips.filter(\.isPinned).sorted { ($0.pinnedAt ?? .distantPast) > ($1.pinnedAt ?? .distantPast) } }

    func clip(_ id: UUID) -> Clip? { clips.first { $0.id == id } }

    func isExcluded(_ bundleID: String?) -> Bool {
        guard let id = bundleID else { return false }
        return excluded.contains { $0.bundleID == id }
    }

    // MARK: Ekleme

    func addText(_ text: String, from app: NSRunningApplication?) {
        if let i = clips.firstIndex(where: { !$0.isImage && $0.text == text }) {
            clips[i].date = Date()
        } else {
            clips.append(Clip(text: text, appBundleID: app?.bundleIdentifier, appName: app?.localizedName))
        }
        trim(); save()
    }

    func addImage(png: Data, width: Int, height: Int, from app: NSRunningApplication?) {
        let hash = SHA256.hash(data: png).map { String(format: "%02x", $0) }.joined()
        if let i = clips.firstIndex(where: { $0.imageHash == hash }) {
            clips[i].date = Date()
        } else {
            let file = "\(UUID().uuidString).png"
            guard (try? png.write(to: ClipImages.url(for: file))) != nil else { return }
            clips.append(Clip(text: "", appBundleID: app?.bundleIdentifier, appName: app?.localizedName,
                              imageFile: file, imageHash: hash, imageWidth: width, imageHeight: height))
        }
        trim(); save()
    }

    // MARK: Değiştirme

    /// Kullanılan kaydı "son kopyalanan" yapar
    func touch(_ id: UUID) {
        guard let i = clips.firstIndex(where: { $0.id == id }) else { return }
        clips[i].date = Date()
        save()
    }

    func togglePin(_ id: UUID) {
        guard let i = clips.firstIndex(where: { $0.id == id }) else { return }
        if clips[i].isPinned {
            clips[i].pinnedAt = nil
            clips[i].date = Date()
        } else {
            clips[i].pinnedAt = Date()
        }
        trim(); save()
    }

    func delete(_ id: UUID) {
        guard let c = clip(id) else { return }
        removeFile(of: c)
        clips.removeAll { $0.id == id }
        save()
    }

    /// Son kopyalananları siler, sık kullanılanlar kalır
    func clearRecent() {
        for c in clips where !c.isPinned { removeFile(of: c) }
        clips.removeAll { !$0.isPinned }
        save()
    }

    // MARK: Disk

    /// Sık kullanılanlar sınıra dahil değil; sadece son kopyalananlar kırpılır
    private func trim() {
        let r = recent
        guard r.count > limit else { return }
        for c in r[limit...] {
            removeFile(of: c)
            clips.removeAll { $0.id == c.id }
        }
    }

    private func removeFile(of c: Clip) {
        guard persist, let f = c.imageFile else { return }
        try? FileManager.default.removeItem(at: ClipImages.url(for: f))
        ClipImages.forget(f)
    }

    private func load() {
        if let data = defaults.data(forKey: "clips"),
           let list = try? JSONDecoder().decode([Clip].self, from: data) {
            clips = list
        } else if let old = defaults.stringArray(forKey: "history") {
            // ilk sürümden kalan geçmişi taşı
            let now = Date()
            clips = old.enumerated().map { Clip(text: $0.element, date: now.addingTimeInterval(-Double($0.offset))) }
            defaults.removeObject(forKey: "history")
        }
        trim(); save()
    }

    private func save() {
        guard persist, let data = try? JSONEncoder().encode(clips) else { return }
        defaults.set(data, forKey: "clips")
    }
}
