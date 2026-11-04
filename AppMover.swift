import Cocoa

/// Uygulama DMG'den ya da İndirilenler'den açıldıysa kendini Uygulamalar klasörüne taşır ve yeniden açılır.
enum AppMover {
    /// Taşıyıp yeniden başlatıyorsa true döner (o zaman uygulama kapanacak, başka bir şey yapma)
    static func moveIfNeeded() -> Bool {
        let src = Bundle.main.bundleURL.resolvingSymlinksInPath()
        let path = src.path
        let home = FileManager.default.homeDirectoryForCurrentUser.path

        // Zaten bir Uygulamalar klasöründeyse ya da geliştirici derlemesiyse dokunma
        if path.hasPrefix("/Applications/") || path.hasPrefix(home + "/Applications/") { return false }
        if path.contains("/build/") && !path.contains("AppTranslocation") { return false }
        if UserDefaults.standard.bool(forKey: "dontAskMove") { return false }

        let alert = NSAlert()
        alert.icon = NSApp.applicationIconImage
        alert.messageText = "Pano Geçmişi'ni Uygulamalar klasörüne taşıyayım mı?"
        alert.informativeText = "Böylece her zaman Uygulamalar'da durur ve Mac açılınca kendiliğinden başlayabilir."
        alert.addButton(withTitle: "Taşı")
        alert.addButton(withTitle: "Taşıma")
        alert.showsSuppressionButton = true
        alert.suppressionButton?.title = "Bir daha sorma"
        NSApp.activate(ignoringOtherApps: true)
        let answer = alert.runModal()
        if alert.suppressionButton?.state == .on { UserDefaults.standard.set(true, forKey: "dontAskMove") }
        guard answer == .alertFirstButtonReturn else { return false }

        let fm = FileManager.default
        let name = src.lastPathComponent
        var dest = URL(fileURLWithPath: "/Applications").appendingPathComponent(name)
        if !fm.isWritableFile(atPath: "/Applications") {
            // yönetici olmayan kullanıcılar için ~/Applications
            let userApps = URL(fileURLWithPath: home).appendingPathComponent("Applications")
            try? fm.createDirectory(at: userApps, withIntermediateDirectories: true)
            dest = userApps.appendingPathComponent(name)
        }

        // Açık olan eski sürümü kapat, eskisini çöpe at
        let me = ProcessInfo.processInfo.processIdentifier
        for other in NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier ?? "")
        where other.processIdentifier != me {
            other.terminate()
        }
        Thread.sleep(forTimeInterval: 0.5)

        do {
            if fm.fileExists(atPath: dest.path) { try fm.trashItem(at: dest, resultingItemURL: nil) }
            try fm.copyItem(at: src, to: dest)
        } catch {
            let a = NSAlert()
            a.messageText = "Taşınamadı"
            a.informativeText = "Uygulamayı Uygulamalar klasörüne elle sürükleyebilirsin.\n\n\(error.localizedDescription)"
            a.runModal()
            return false
        }

        // İndirilenler gibi yazılabilir bir yerdeyse orijinali çöpe at (DMG salt okunurdur, ona dokunulmaz)
        if !path.contains("AppTranslocation"), fm.isDeletableFile(atPath: path) {
            try? fm.trashItem(at: src, resultingItemURL: nil)
        }

        // Yeni yerinden yeniden aç
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/sh")
        p.arguments = ["-c", "sleep 1; /usr/bin/open \"$0\"", dest.path]
        try? p.run()
        NSApp.terminate(nil)
        return true
    }
}
