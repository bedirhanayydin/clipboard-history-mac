import Cocoa

/// Geçmişteki tek bir kayıt (metin ya da resim)
struct Clip: Codable, Equatable, Identifiable {
    var id: UUID
    var text: String
    var date: Date
    var appBundleID: String?
    var appName: String?
    /// Sabitlendiyse sabitlenme zamanı ("Sık kullanılanlar" sekmesi)
    var pinnedAt: Date?
    /// Resimse: Images klasöründeki dosya adı
    var imageFile: String?
    var imageHash: String?
    var imageWidth: Int?
    var imageHeight: Int?

    var isPinned: Bool { pinnedAt != nil }
    var isImage: Bool { imageFile != nil }

    init(text: String, date: Date = Date(), appBundleID: String? = nil, appName: String? = nil,
         imageFile: String? = nil, imageHash: String? = nil, imageWidth: Int? = nil, imageHeight: Int? = nil) {
        self.id = UUID()
        self.text = text
        self.date = date
        self.appBundleID = appBundleID
        self.appName = appName
        self.imageFile = imageFile
        self.imageHash = imageHash
        self.imageWidth = imageWidth
        self.imageHeight = imageHeight
    }

    // Eski sürümlerin kayıtlarında olmayan alanlar boş gelir
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        text = try c.decodeIfPresent(String.self, forKey: .text) ?? ""
        date = try c.decodeIfPresent(Date.self, forKey: .date) ?? Date()
        appBundleID = try c.decodeIfPresent(String.self, forKey: .appBundleID)
        appName = try c.decodeIfPresent(String.self, forKey: .appName)
        pinnedAt = try c.decodeIfPresent(Date.self, forKey: .pinnedAt)
        imageFile = try c.decodeIfPresent(String.self, forKey: .imageFile)
        imageHash = try c.decodeIfPresent(String.self, forKey: .imageHash)
        imageWidth = try c.decodeIfPresent(Int.self, forKey: .imageWidth)
        imageHeight = try c.decodeIfPresent(Int.self, forKey: .imageHeight)
    }

    enum Kind {
        case link, email, number, multiline, text, image

        var symbol: String {
            switch self {
            case .link: return "link"
            case .email: return "envelope"
            case .number: return "number"
            case .multiline: return "text.alignleft"
            case .text: return "text.quote"
            case .image: return "photo"
            }
        }

        var title: String {
            switch self {
            case .link: return "Bağlantı"
            case .email: return "E-posta"
            case .number: return "Sayı"
            case .multiline: return "Çok satırlı metin"
            case .text: return "Metin"
            case .image: return "Resim"
            }
        }
    }

    var kind: Kind {
        if isImage { return .image }
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let noSpaces = !t.contains(where: \.isWhitespace)
        if noSpaces, let u = URL(string: t), let s = u.scheme, ["http", "https"].contains(s), u.host != nil {
            return .link
        }
        if noSpaces, t.range(of: #"^[^@\s]+@[^@\s]+\.[^@\s]+$"#, options: .regularExpression) != nil {
            return .email
        }
        if t.contains(where: \.isNumber),
           t.allSatisfy({ $0.isNumber || " +-.,()/".contains($0) }) {
            return .number
        }
        return text.contains(where: \.isNewline) ? .multiline : .text
    }

    var lineCount: Int { text.split(whereSeparator: \.isNewline).count }

    var sizeText: String {
        if isImage { return "\(imageWidth ?? 0) × \(imageHeight ?? 0) piksel" }
        return "\(text.count) karakter" + (lineCount > 1 ? "  ·  \(lineCount) satır" : "")
    }

    /// Tek satırlık önizleme
    var preview: String {
        if isImage { return "Resim  ·  \(imageWidth ?? 0)×\(imageHeight ?? 0)" }
        return text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: "  ⏎  ")
    }
}

/// Uygulama ikonlarını tekrar tekrar diskten okumamak için önbellek
enum AppIcons {
    private static var cache: [String: NSImage] = [:]

    static func icon(for bundleID: String?) -> NSImage? {
        guard let id = bundleID else { return nil }
        if let i = cache[id] { return i }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) else { return nil }
        let img = NSWorkspace.shared.icon(forFile: url.path)
        cache[id] = img
        return img
    }
}

/// Kaydedilmiş resimleri okur (önbellekli)
enum ClipImages {
    static let directory: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("PanoGecmisi/Images", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    private static var cache: [String: NSImage] = [:]

    static func url(for file: String) -> URL {
        file.hasPrefix("/") ? URL(fileURLWithPath: file) : directory.appendingPathComponent(file)
    }

    static func image(for clip: Clip) -> NSImage? {
        guard let f = clip.imageFile else { return nil }
        if let i = cache[f] { return i }
        guard let img = NSImage(contentsOf: url(for: f)) else { return nil }
        cache[f] = img
        return img
    }

    static func forget(_ file: String) { cache[file] = nil }
}

enum TimeText {
    private static let relative: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.locale = Locale(identifier: "tr_TR")
        f.unitsStyle = .short
        return f
    }()

    private static let exact: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "tr_TR")
        f.dateFormat = "d MMMM, HH:mm"
        return f
    }()

    static func short(_ d: Date) -> String {
        let s = Date().timeIntervalSince(d)
        if s < 45 { return "şimdi" }
        if s < 3600 { return "\(Int(s / 60)) dk" }
        if s < 86400 { return "\(Int(s / 3600)) sa" }
        return "\(Int(s / 86400)) g"
    }

    static func long(_ d: Date) -> String {
        Date().timeIntervalSince(d) < 45 ? "Az önce" : relative.localizedString(for: d, relativeTo: Date())
    }

    static func exactText(_ d: Date) -> String { exact.string(from: d) }
}

/// Türkçe'ye uygun, büyük/küçük harf ve aksan duyarsız karşılaştırma için
func fold(_ s: String) -> String {
    s.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "tr_TR"))
}
