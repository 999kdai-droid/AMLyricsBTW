import Foundation

struct TranslationService {

    private static let geniusToken = "BGTdcoZt6qzt14l-uQrL6rjmZ9gmJtWTvKXe7miyjI6K9vlfuloIW2Hp-BGt8V4m"
    private static let geminiKey   = "AIzaSyD-pLdqpXDlG80x1bPgGigEFqGRaFiAbxM"
    private static let netEaseBase = "http://localhost:3335"

    // ── キャッシュ ──
    private static var memoryCache: [String: [String]] = [:]

    private static var cacheFileURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = dir.appendingPathComponent("AMLyricsBTW")
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        return appDir.appendingPathComponent("translation_cache.json")
    }

    private static func loadDiskCache() -> [String: [String]] {
        guard let data = try? Data(contentsOf: cacheFileURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: [String]] else { return [:] }
        return json
    }

    private static func cacheKey(title: String, artist: String) -> String {
        "\(artist)___\(title)".lowercased()
    }

    private static func cachedTranslation(title: String, artist: String) -> [String]? {
        let key = cacheKey(title: title, artist: artist)
        if let mem = memoryCache[key] { print("💾 翻訳キャッシュヒット（メモリ）: \(title)"); return mem }
        let disk = loadDiskCache()
        if let saved = disk[key] { memoryCache[key] = saved; print("💾 翻訳キャッシュヒット（ディスク）: \(title)"); return saved }
        return nil
    }

    private static func saveToCache(title: String, artist: String, translations: [String]) {
        let key = cacheKey(title: title, artist: artist)
        memoryCache[key] = translations
        var disk = loadDiskCache()
        disk[key] = translations
        if let data = try? JSONSerialization.data(withJSONObject: disk) { try? data.write(to: cacheFileURL) }
        print("💾 翻訳キャッシュ保存: \(title) (\(translations.count)行)")
    }

    private static func applyTranslations(to lines: [LyricLine], translations: [String]) -> [LyricLine] {
        var result = lines
        for i in lines.indices where i < translations.count { result[i].translation = translations[i] }
        return result
    }

    // ── メインエントリ ──
    static func fetchTranslation(lines: [LyricLine], title: String, artist: String) async -> [LyricLine] {
        if let cached = cachedTranslation(title: title, artist: artist) {
            return applyTranslations(to: lines, translations: cached)
        }
        // 1. NetEase（日本語訳が豊富）
        if let result = await fromNetEase(lines: lines, title: title, artist: artist) {
            print("✅ 翻訳ソース: NetEase")
            saveToCache(title: title, artist: artist, translations: result.compactMap { $0.translation })
            return result
        }
        // 2. Genius（ファン投稿和訳）
        if let result = await fromGenius(title: title, artist: artist, lines: lines) {
            print("✅ 翻訳ソース: Genius")
            saveToCache(title: title, artist: artist, translations: result.compactMap { $0.translation })
            return result
        }
        // 3. LRCLIB日本語版
        if let result = await fromLRCLIB(title: title, artist: artist, lines: lines) {
            print("✅ 翻訳ソース: LRCLIB")
            return result
        }
        // 4. Gemini意訳
        if let result = await fromGemini(lines: lines, title: title, artist: artist) {
            print("✅ 翻訳ソース: Gemini")
            saveToCache(title: title, artist: artist, translations: result.compactMap { $0.translation })
            return result
        }
        // 5. Apple Translation
        print("⚠️ 翻訳ソース: Apple Translation（フォールバック）")
        return lines
    }

    // ── 1. NetEase Cloud Music ──
    private static func fromNetEase(lines: [LyricLine], title: String, artist: String) async -> [LyricLine]? {
        let variants = LRCLIBService.titleVariants(of: title)
        for variant in variants {
            if let result = await netEaseSearch(lines: lines, title: variant, artist: artist) { return result }
        }
        return nil
    }

    private static func netEaseSearch(lines: [LyricLine], title: String, artist: String) async -> [LyricLine]? {
        let query = "\(title) \(artist)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        guard let searchURL = URL(string: "\(netEaseBase)/search?keywords=\(query)&limit=5") else { return nil }
        guard let (data, _) = try? await URLSession.shared.data(from: searchURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let result = json["result"] as? [String: Any],
              let songs = result["songs"] as? [[String: Any]] else {
            print("NetEase: 検索失敗")
            return nil
        }
        for song in songs {
            guard let id = song["id"] as? Int else { continue }
            let songName = (song["name"] as? String ?? "").lowercased()
            let artists = (song["artists"] as? [[String: Any]] ?? []).compactMap { $0["name"] as? String }.joined(separator: " ").lowercased()
            // 曲名とアーティストが一致するか確認
            guard songName.contains(title.lowercased().prefix(10)) ||
                  title.lowercased().contains(songName.prefix(10)) else { continue }
            print("NetEase: 曲発見 id=\(id) \(songName) / \(artists)")
            if let result = await netEaseLyrics(id: id, lines: lines) { return result }
        }
        return nil
    }

    private static func netEaseLyrics(id: Int, lines: [LyricLine]) async -> [LyricLine]? {
        guard let url = URL(string: "\(netEaseBase)/lyric?id=\(id)") else { return nil }
        guard let (data, _) = try? await URLSession.shared.data(from: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }

        // tlyric = 翻訳歌詞（日本語訳）
        if let tlyric = json["tlyric"] as? [String: Any],
           let lyricStr = tlyric["lyric"] as? String, !lyricStr.isEmpty {
            let jaLines = LRCParser.parse( lyricStr)
                .map { $0.text }
                .filter { !$0.isEmpty && $0.range(of: #"[\u3040-\u30FF\u4E00-\u9FFF]"#, options: .regularExpression) != nil }
            if jaLines.count >= lines.count / 3 {
                print("NetEase: 日本語訳 \(jaLines.count)行")
                return alignTranslation(original: lines, translated: jaLines)
            }
        }
        // lyric = 原語歌詞（日本の曲の場合ここに日本語が入ることも）
        if let lyric = json["lyric"] as? [String: Any],
           let lyricStr = lyric["lyric"] as? String {
            let jaLines = LRCParser.parse( lyricStr)
                .map { $0.text }
                .filter { !$0.isEmpty && $0.range(of: #"[\u3040-\u30FF\u4E00-\u9FFF]"#, options: .regularExpression) != nil }
            if jaLines.count >= lines.count / 3 {
                print("NetEase: 日本語歌詞 \(jaLines.count)行")
                return alignTranslation(original: lines, translated: jaLines)
            }
        }
        return nil
    }

    // ── 2. Genius ──
    private static func fromGenius(title: String, artist: String, lines: [LyricLine]) async -> [LyricLine]? {
        let variants = LRCLIBService.titleVariants(of: title)
        for variant in variants {
            if let result = await geniusSearch(title: variant, artist: artist, lines: lines) { return result }
        }
        return nil
    }

    private static func geniusSearch(title: String, artist: String, lines: [LyricLine]) async -> [LyricLine]? {
        var search = URLComponents(string: "https://api.genius.com/search")!
        search.queryItems = [.init(name: "q", value: "\(title) \(artist)")]
        guard let searchURL = search.url else { return nil }
        var req = URLRequest(url: searchURL)
        req.setValue("Bearer \(geniusToken)", forHTTPHeaderField: "Authorization")
        req.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")
        req.timeoutInterval = 15
        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let response = json["response"] as? [String: Any],
              let hits = response["hits"] as? [[String: Any]],
              let first = hits.first,
              let result = first["result"] as? [String: Any],
              let path = result["path"] as? String else { return nil }

        print("Genius: 曲発見 → \(path)")
        var pageReq = URLRequest(url: URL(string: "https://genius.com\(path)")!)
        pageReq.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")
        pageReq.setValue("text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")
        pageReq.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")
        pageReq.timeoutInterval = 15
        guard let (html, _) = try? await URLSession.shared.data(for: pageReq),
              let htmlStr = String(data: html, encoding: .utf8) else { return nil }
        let jaLines = extractJapaneseLyrics(from: htmlStr)
        print("Genius: 日本語行数 = \(jaLines.count)")
        guard jaLines.count >= lines.count / 3 else { return nil }
        return alignTranslation(original: lines, translated: jaLines)
    }

    private static func extractJapaneseLyrics(from html: String) -> [String] {
        var results: [String] = []
        let pattern = #"data-lyrics-container="true"[^>]*>(.*?)</div>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else { return [] }
        for match in regex.matches(in: html, range: NSRange(html.startIndex..., in: html)) {
            if let r = Range(match.range(at: 1), in: html) {
                var chunk = String(html[r])
                chunk = chunk.replacingOccurrences(of: #"<br\s*/?>"#, with: "\n", options: .regularExpression)
                chunk = chunk.replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression)
                let decoded = chunk
                    .replacingOccurrences(of: "&amp;", with: "&")
                    .replacingOccurrences(of: "&quot;", with: "\"")
                    .replacingOccurrences(of: "&#x27;", with: "'")
                results.append(contentsOf: decoded.components(separatedBy: "\n")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty })
            }
        }
        return results.filter { $0.range(of: #"[\u3040-\u30FF\u4E00-\u9FFF]"#, options: .regularExpression) != nil }
    }

    // ── 3. LRCLIB日本語版 ──
    private static func fromLRCLIB(title: String, artist: String, lines: [LyricLine]) async -> [LyricLine]? {
        let variants = LRCLIBService.titleVariants(of: title)
        for variant in variants {
            var components = URLComponents(string: "https://lrclib.net/api/get")!
            components.queryItems = [
                .init(name: "track_name", value: variant),
                .init(name: "artist_name", value: artist),
                .init(name: "language", value: "ja")
            ]
            guard let url = components.url,
                  let (data, _) = try? await URLSession.shared.data(from: url),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }
            let lrcText = (json["syncedLyrics"] as? String) ?? (json["plainLyrics"] as? String) ?? ""
            let jaLines = lrcText.components(separatedBy: "\n")
                .map { $0.replacingOccurrences(of: #"^\[\d{2}:\d{2}\.\d+\]\s*"#, with: "", options: .regularExpression) }
                .filter { !$0.isEmpty && $0.range(of: #"[\u3040-\u30FF\u4E00-\u9FFF]"#, options: .regularExpression) != nil }
            if !jaLines.isEmpty { return alignTranslation(original: lines, translated: jaLines) }
        }
        return nil
    }

    // ── 4. Gemini意訳 ──
    private static func fromGemini(lines: [LyricLine], title: String, artist: String) async -> [LyricLine]? {
        let numbered = lines.enumerated().map { "\($0.offset+1)|\($0.element.text)" }.joined(separator: "\n")
        let prompt = """
        あなたはヒップホップ・R&B専門のプロ翻訳家です。
        「\(title)」by \(artist) の歌詞を日本語に意訳してください。

        ルール：
        - 直訳ではなく、日本語のヒップホップ・R&Bとして自然で詩的な意訳にすること
        - ラップスラングや黒人英語（AAVE）を適切に意訳すること
          例: "finna"→「〜しようとしてる」, "racks"→「大金」, "drip"→「イケてるファッション」,
              "cap/no cap"→「嘘/マジで」, "hood"→「地元」, "plug"→「売人/コネ」,
              "bussin"→「最高」, "slime"→「相棒」, "deadass"→「マジで」,
              "on sight"→「即やる」, "sauce"→「スタイル」, "finesse"→「うまく騙す」,
              "bling"→「派手なアクセサリー」, "flex"→「見せびらかす」, "clout"→「影響力」
        - 韻やリズム感を日本語でも意識すること
        - 行番号|翻訳文 の形式で、元と完全に同じ行数だけ返すこと
        - 説明・前置き・マークダウン記号は一切不要。翻訳のみ返すこと

        歌詞：
        \(numbered)
        """
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.1-flash-lite-preview:generateContent?key=\(geminiKey)") else { return nil }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 60
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["contents": [["parts": [["text": prompt]]]]])
        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            if let http = response as? HTTPURLResponse { print("Gemini HTTP status: \(http.statusCode)") }
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
            if let error = json["error"] as? [String: Any] { print("Gemini APIエラー: \(error["message"] ?? "不明")"); return nil }
            guard let candidates = json["candidates"] as? [[String: Any]],
                  let content = candidates.first?["content"] as? [String: Any],
                  let parts = content["parts"] as? [[String: Any]],
                  let text = parts.first?["text"] as? String else { return nil }
            var result = lines
            for line in text.components(separatedBy: "\n") {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty else { continue }
                let parts = trimmed.components(separatedBy: "|")
                guard parts.count >= 2, let idx = Int(parts[0]), idx >= 1, idx <= result.count else { continue }
                result[idx - 1].translation = parts[1...].joined(separator: "|").trimmingCharacters(in: .whitespaces)
            }
            let filled = result.filter { $0.translation != nil }.count
            print("Gemini: \(filled)/\(lines.count)行翻訳済み")
            guard filled >= lines.count / 2 else { return nil }
            return result
        } catch { print("Gemini 通信エラー: \(error)"); return nil }
    }

    private static func alignTranslation(original: [LyricLine], translated: [String]) -> [LyricLine] {
        var result = original
        let ratio = Double(translated.count) / Double(original.count)
        for i in original.indices {
            result[i].translation = translated[min(Int(Double(i) * ratio), translated.count - 1)]
        }
        return result
    }
}
