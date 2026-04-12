import SwiftUI

// ── 英語音素近似 ──
private func simplifyPhonetic(_ word: String) -> String {
    var w = word.lowercased()
    let rules: [(String,String)] = [
        ("tion","shun"),("sion","shun"),("ck","k"),("ph","f"),
        ("gh",""),("kn","n"),("wr","r"),("qu","kw"),
        ("oo","u"),("ee","i"),("ea","i"),("ai","ay"),
        ("oa","o"),("igh","ay"),("ight","ayt"),("ould","ood"),
        ("ow","o"),("ou","ow"),("au","aw"),("ew","u"),
        ("dge","j"),("tch","ch"),("ce","s"),("ci","s"),
        ("ge","j"),("gi","j"),
    ]
    for (f,t) in rules { w = w.replacingOccurrences(of: f, with: t) }
    return w
}

private func syllableCount(_ word: String) -> Int {
    let w = word.lowercased().replacingOccurrences(of: #"[^a-z]"#, with: "", options: .regularExpression)
    let vowels: Set<Character> = ["a","e","i","o","u","y"]
    var count = 0; var prev = false
    for ch in w {
        let v = vowels.contains(ch)
        if v && !prev { count += 1 }
        prev = v
    }
    if w.hasSuffix("e") && count > 1 { count -= 1 }
    return max(1, count)
}

// 末尾からn音節分のカーネルを抽出
private func rhymeKernel(_ word: String, syllables: Int = 1) -> String {
    let s = simplifyPhonetic(word)
    let vowels: Set<Character> = ["a","e","i","o","u"]
    var vowelIndices: [String.Index] = []
    var prevV = false
    for idx in s.indices {
        let v = vowels.contains(s[idx])
        if v && !prevV { vowelIndices.append(idx) }
        prevV = v
    }
    guard !vowelIndices.isEmpty else { return String(s.suffix(3)) }
    let start = max(0, vowelIndices.count - syllables)
    return String(s[vowelIndices[start]...])
}

// ── Slant Rhyme（不完全韻）判定 ──
private func isSlantRhyme(_ a: String, _ b: String) -> Bool {
    let ka = rhymeKernel(a)
    let kb = rhymeKernel(b)
    guard ka.count >= 2 && kb.count >= 2 else { return false }
    // 末尾の母音が一致していれば slant rhyme
    let vowels: Set<Character> = ["a","e","i","o","u"]
    let vaLast = ka.last(where: { vowels.contains($0) })
    let vbLast = kb.last(where: { vowels.contains($0) })
    return vaLast != nil && vaLast == vbLast && ka != kb
}

// ── メイン韻検出 ──
struct RhymeDetector {

    // 色定義（Geminiガイドに基づく）
    // 1=Red(A), 2=Blue(B), 3=Green(C), 4=Gold(Internal), 5=Purple(Multi), 6=Orange(D)
    static func rhymeColor(_ index: Int) -> Color {
        switch index {
        case 1: return Color(red: 1.0, green: 0.29, blue: 0.17)  // Vibrant Red
        case 2: return Color(red: 0.0, green: 0.48, blue: 1.0)   // Electric Blue
        case 3: return Color(red: 0.20, green: 0.84, blue: 0.29) // Neon Green
        case 4: return Color(red: 1.0, green: 0.84, blue: 0.04)  // Gold/Amber (Internal)
        case 5: return Color(red: 0.75, green: 0.35, blue: 0.95) // Purple (Multisyllabic)
        case 6: return Color(red: 1.0, green: 0.42, blue: 0.21)  // Orange
        default: return .white
        }
    }

    static func detectRhymes(in lines: [LyricLine]) -> [String: Int] {
        var result: [String: Int] = [:]

        // 各行の単語を展開
        let lineWords: [[String]] = lines.map {
            $0.text.components(separatedBy: .whitespaces)
                .map { $0.lowercased().replacingOccurrences(of: #"[^a-z']"#, with: "", options: .regularExpression) }
                .filter { $0.count >= 2 }
        }

        // ── 1. Multisyllabic（3音節以上）Purple ──
        var kernel3Map: [String: [(Int,Int)]] = [:]
        var kernel2Map: [String: [(Int,Int)]] = [:]
        for (li, words) in lineWords.enumerated() {
            for (wi, word) in words.enumerated() {
                let syl = syllableCount(word)
                if syl >= 3 {
                    let k = rhymeKernel(word, syllables: 3)
                    if k.count >= 4 { kernel3Map[k, default: []].append((li, wi)) }
                }
                if syl >= 2 {
                    let k = rhymeKernel(word, syllables: 2)
                    if k.count >= 3 { kernel2Map[k, default: []].append((li, wi)) }
                }
            }
        }
        for map in [kernel3Map, kernel2Map] {
            for (_, pos) in map where Set(pos.map{$0.0}).count >= 2 {
                for (li, wi) in pos { if result["\(li)_\(wi)"] == nil { result["\(li)_\(wi)"] = 5 } }
            }
        }

        // ── 2. Perfect Rhyme（完全韻）: 1音節カーネル一致 ──
        var kernel1Map: [String: [(Int,Int)]] = [:]
        for (li, words) in lineWords.enumerated() {
            for (wi, word) in words.enumerated() {
                let k = rhymeKernel(word, syllables: 1)
                if k.count >= 2 { kernel1Map[k, default: []].append((li, wi)) }
            }
        }
        // 頻度順にソート → 多い順にA(Red)→B(Blue)→C(Green)→D(Orange)
        let perfectGroups = kernel1Map
            .filter { Set($0.value.map{$0.0}).count >= 2 }
            .sorted { $0.value.count > $1.value.count }
        let endColors = [1, 2, 3, 6]
        var colorIdx = 0
        for (_, pos) in perfectGroups {
            let c = endColors[colorIdx % endColors.count]
            colorIdx += 1
            for (li, wi) in pos { if result["\(li)_\(wi)"] == nil { result["\(li)_\(wi)"] = c } }
        }

        // ── 3. Slant Rhyme（半韻）──
        // 末尾単語のみ、カーネルが違うが母音が一致
        var slantMap: [Character: [(Int,Int)]] = [:]
        for (li, words) in lineWords.enumerated() {
            guard let last = words.last, let wi = words.indices.last else { continue }
            let vowels: Set<Character> = ["a","e","i","o","u"]
            let k = rhymeKernel(last)
            if let vLast = k.last(where: { vowels.contains($0) }) {
                slantMap[vLast, default: []].append((li, wi))
            }
        }
        for (_, pos) in slantMap where Set(pos.map{$0.0}).count >= 2 {
            for (li, wi) in pos { if result["\(li)_\(wi)"] == nil { result["\(li)_\(wi)"] = 2 } }
        }

        // ── 4. Internal Rhyme（中韻）Gold ──
        // 行の途中の単語が他の行の単語と韻を踏む
        var internalMap: [String: [(Int,Int)]] = [:]
        for (li, words) in lineWords.enumerated() {
            for (wi, word) in words.dropLast().enumerated() {
                let k = rhymeKernel(word)
                if k.count >= 2 { internalMap[k, default: []].append((li, wi)) }
            }
        }
        for (kernel, pos) in internalMap where Set(pos.map{$0.0}).count >= 2 {
            for (li, wi) in pos {
                if result["\(li)_\(wi)"] == nil {
                    let words = lineWords[li]
                    if wi < words.count - 1 { result["\(li)_\(wi)"] = 4 }
                }
            }
        }

        // ── 5. Bigram（連続2単語）──
        var bigramMap: [String: [(Int,Int,Int)]] = [:]
        for (li, words) in lineWords.enumerated() {
            for wi in 0..<(words.count-1) {
                let k = rhymeKernel(words[wi], syllables: 1) + "_" + rhymeKernel(words[wi+1], syllables: 1)
                if k.count >= 5 { bigramMap[k, default: []].append((li, wi, wi+1)) }
            }
        }
        for (_, pos) in bigramMap where Set(pos.map{$0.0}).count >= 2 {
            for (li, wi1, wi2) in pos {
                if result["\(li)_\(wi1)"] == nil { result["\(li)_\(wi1)"] = 3 }
                if result["\(li)_\(wi2)"] == nil { result["\(li)_\(wi2)"] = 3 }
            }
        }

        return result
    }
}
