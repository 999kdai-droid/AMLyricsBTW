import Foundation

struct LRCLIBService {

    private static var lyricsCache: [String: [LyricLine]] = [:]

    private static var lyricsCacheFileURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = dir.appendingPathComponent("AMLyricsBTW")
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        return appDir.appendingPathComponent("lyrics_cache.json")
    }

    private static func cacheKey(title: String, artist: String) -> String {
        "\(artist)___\(title)".lowercased()
    }

    private static func cachedLyrics(title: String, artist: String) -> [LyricLine]? {
        let key = cacheKey(title: title, artist: artist)
        if let mem = lyricsCache[key] { print("💾 歌詞キャッシュヒット（メモリ）: \(title)"); return mem }
        guard let data = try? Data(contentsOf: lyricsCacheFileURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: [[String: Any]]],
              let saved = json[key] else { return nil }
        let lines = saved.compactMap { dict -> LyricLine? in
            guard let ts = dict["t"] as? Double, let text = dict["x"] as? String else { return nil }
            return LyricLine(timestamp: ts, text: text)
        }
        lyricsCache[key] = lines
        print("💾 歌詞キャッシュヒット（ディスク）: \(title)")
        return lines
    }

    private static func saveLyricsCache(title: String, artist: String, lines: [LyricLine]) {
        let key = cacheKey(title: title, artist: artist)
        lyricsCache[key] = lines
        var disk: [String: [[String: Any]]] = [:]
        if let data = try? Data(contentsOf: lyricsCacheFileURL),
           let existing = try? JSONSerialization.jsonObject(with: data) as? [String: [[String: Any]]] { disk = existing }
        disk[key] = lines.map { ["t": $0.timestamp, "x": $0.text] }
        if let data = try? JSONSerialization.data(withJSONObject: disk) { try? data.write(to: lyricsCacheFileURL) }
        print("💾 歌詞キャッシュ保存: \(title) (\(lines.count)行)")
    }

    static func titleVariants(of title: String) -> [String] {
        var variants = [title]
        let patterns = [
            #"\s*[\(\[].*?(deluxe|remaster|remastered|anniversary|edition|version|explicit|clean|bonus|extended|feat\.|ft\.).*?[\)\]]"#,
            #"\s*[\(\[][^\)\]]*[\)\]]$"#,
        ]
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let cleaned = regex.stringByReplacingMatches(
                    in: title, range: NSRange(title.startIndex..., in: title), withTemplate: ""
                ).trimmingCharacters(in: CharacterSet.whitespaces)
                if !cleaned.isEmpty && cleaned != title { variants.append(cleaned) }
            }
        }
        return Array(NSOrderedSet(array: variants)) as! [String]
    }

    static func fetchLyrics(title: String, artist: String) async -> [LyricLine] {
        if let cached = cachedLyrics(title: title, artist: artist) { return cached }

        // 1. /api/search（あいまい検索・メイン）
        if let lines = await searchLRCLIB(title: title, artist: artist) {
            saveLyricsCache(title: title, artist: artist, lines: lines)
            return lines
        }

        // 2. タイトルバリエーションでも試す
        for variant in titleVariants(of: title) where variant != title {
            if let lines = await searchLRCLIB(title: variant, artist: artist) {
                saveLyricsCache(title: title, artist: artist, lines: lines)
                return lines
            }
        }

        // 3. アーティスト名なしで再検索
        if let lines = await searchLRCLIB(title: title, artist: "") {
            saveLyricsCache(title: title, artist: artist, lines: lines)
            return lines
        }

        print("🎵 歌詞が見つかりませんでした: \(title)")
        return []
    }

    private static func searchLRCLIB(title: String, artist: String) async -> [LyricLine]? {
        var components = URLComponents(string: "https://lrclib.net/api/search")!
        var queryItems: [URLQueryItem] = [.init(name: "track_name", value: title)]
        if !artist.isEmpty { queryItems.append(.init(name: "artist_name", value: artist)) }
        components.queryItems = queryItems
        guard let url = components.url else { return nil }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let results = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return nil }

            // 同期歌詞があるものを優先
            let sorted = results.sorted {
                let a = ($0["syncedLyrics"] as? String ?? "").isEmpty
                let b = ($1["syncedLyrics"] as? String ?? "").isEmpty
                return !a && b
            }

            for result in sorted {
                let trackName = (result["trackName"] as? String ?? "").lowercased()
                let queryTitle = title.lowercased()

                // タイトルが部分一致するか確認
                guard trackName.contains(queryTitle.prefix(10)) ||
                      queryTitle.contains(trackName.prefix(10)) else { continue }

                if let synced = result["syncedLyrics"] as? String, !synced.isEmpty {
                    var lines = LRCParser.parse(synced)
                    lines = lines.filter {
                        !$0.text.lowercased().contains("instrumental") &&
                        !$0.text.trimmingCharacters(in: CharacterSet.whitespaces).isEmpty
                    }
                    if lines.isEmpty { continue }
                    print("✅ 歌詞ソース: LRCLIB search（同期）\(lines.count)行 [\(result["trackName"] ?? "")]")
                    return lines
                }

                if let plain = result["plainLyrics"] as? String, !plain.isEmpty {
                    let lines = plain.components(separatedBy: "\n").enumerated().compactMap { i, line -> LyricLine? in
                        let t = line.trimmingCharacters(in: CharacterSet.whitespaces)
                        guard !t.isEmpty, !t.lowercased().contains("instrumental") else { return nil }
                        return LyricLine(timestamp: Double(i) * 3.0, text: t)
                    }
                    if lines.isEmpty { continue }
                    print("✅ 歌詞ソース: LRCLIB search（平文）\(lines.count)行 [\(result["trackName"] ?? "")]")
                    return lines
                }
            }
        } catch { print("🎵 LRCLIB search エラー: \(error)") }
        return nil
    }

    // TranslationServiceから呼ばれる日本語版検索
    static func fetchFromLRCLIB(title: String, artist: String) async -> [LyricLine]? {
        return await searchLRCLIB(title: title, artist: artist)
    }
}
