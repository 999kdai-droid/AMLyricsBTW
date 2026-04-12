import SwiftUI

// ── 韻検出ユーティリティ ──
struct RhymeDetector {
    // 行末の単語から韻を踏んでいるグループを検出
    static func detectRhymes(in lines: [LyricLine]) -> [String: Int] {
        // 単語末尾の母音+子音パターンで韻を判定
        var endings: [String: [Int]] = [:]
        for (i, line) in lines.enumerated() {
            let words = line.text.lowercased()
                .components(separatedBy: .whitespaces)
                .filter { !$0.isEmpty }
            guard let last = words.last else { continue }
            let clean = last.replacingOccurrences(of: #"[^a-z]"#, with: "", options: .regularExpression)
            guard clean.count >= 2 else { continue }
            // 末尾3〜4文字で韻を判定
            let suffix = String(clean.suffix(3))
            endings[suffix, default: []].append(i)
        }
        // 2行以上で同じ末尾 → 韻グループに割り当て
        var result: [String: Int] = [:]
        var groupIndex = 0
        let rhymeColors = [1, 2, 3, 4, 5, 6]
        for (suffix, indices) in endings where indices.count >= 2 {
            let colorIdx = rhymeColors[groupIndex % rhymeColors.count]
            for i in indices {
                let key = "\(i)_end"
                result[key] = colorIdx
            }
            groupIndex += 1
        }
        return result
    }

    static func rhymeColor(_ index: Int) -> Color {
        switch index {
        case 1: return Color(hue: 0.0,  saturation: 0.7, brightness: 0.95) // 赤
        case 2: return Color(hue: 0.08, saturation: 0.8, brightness: 0.95) // オレンジ
        case 3: return Color(hue: 0.55, saturation: 0.7, brightness: 0.95) // 青
        case 4: return Color(hue: 0.75, saturation: 0.6, brightness: 0.95) // 紫
        case 5: return Color(hue: 0.35, saturation: 0.7, brightness: 0.85) // 緑
        case 6: return Color(hue: 0.15, saturation: 0.8, brightness: 0.95) // 黄
        default: return .primary
        }
    }
}

// ── メインスクロールビュー ──
struct LyricsScrollView: View {
    let lines: [LyricLine]
    let currentTime: Double
    let showTranslation: Bool
    let offset: Double

    @State private var rhymeMap: [String: Int] = [:]

    var adjustedTime: Double { currentTime + offset }

    var activeIndex: Int {
        var result = 0
        for (i, line) in lines.enumerated() {
            if line.timestamp <= adjustedTime { result = i }
        }
        return result
    }

    var nextTimestamp: Double {
        let next = activeIndex + 1
        return next < lines.count ? lines[next].timestamp : (lines.last?.timestamp ?? 0) + 5
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    Color.clear.frame(height: 180)
                    ForEach(Array(lines.enumerated()), id: \.element.id) { i, line in
                        LyricLineView(
                            line: line,
                            lineIndex: i,
                            isActive: i == activeIndex,
                            isPast: i < activeIndex,
                            showTranslation: showTranslation,
                            currentTime: adjustedTime,
                            nextTimestamp: i == activeIndex ? nextTimestamp : 0,
                            rhymeColorIndex: rhymeMap["\(i)_end"]
                        )
                        .id(i)
                    }
                    Color.clear.frame(height: 250)
                }
            }
            .onChange(of: activeIndex) { _, idx in
                withAnimation(.spring(response: 0.5, dampingFraction: 0.78)) {
                    proxy.scrollTo(idx, anchor: .center)
                }
            }
        }
        .onAppear { rhymeMap = RhymeDetector.detectRhymes(in: lines) }
        .onChange(of: lines.count) { _, _ in rhymeMap = RhymeDetector.detectRhymes(in: lines) }
    }
}

// ── 1行ビュー ──
struct LyricLineView: View {
    let line: LyricLine
    let lineIndex: Int
    let isActive: Bool
    let isPast: Bool
    let showTranslation: Bool
    let currentTime: Double
    let nextTimestamp: Double
    let rhymeColorIndex: Int?

    var lineProgress: Double {
        guard isActive else { return isActive ? 1.0 : 0.0 }
        
        // timedWords がある場合：より正確な進度計算
        if let timedWords = line.timedWords, !timedWords.isEmpty {
            let totalDuration = (timedWords.last?.timestamp ?? 0) + (timedWords.last?.duration ?? 1)
            let elapsed = currentTime - line.timestamp
            
            if elapsed < 0 { return 0.0 }
            if elapsed >= totalDuration { return 1.0 }
            
            return elapsed / max(totalDuration, 0.1)
        }
        
        // timedWords がない場合：行全体の進度
        let duration = nextTimestamp - line.timestamp
        guard duration > 0 else { return isActive ? 1.0 : 0.0 }
        
        let elapsed = currentTime - line.timestamp
        return min(max(elapsed / duration, 0), 1)
    }

    var body: some View {
        VStack(alignment: .center, spacing: 6) {
            if isActive {
                KaraokeTextView(
                    text: line.text,
                    progress: lineProgress,
                    rhymeColorIndex: rhymeColorIndex,
                    timedWords: line.timedWords
                )
                .padding(.horizontal, 20)
            } else {
                RhymeAwareText(
                    text: line.text,
                    isPast: isPast,
                    rhymeColorIndex: rhymeColorIndex
                )
                .padding(.horizontal, 24)
            }

            if showTranslation, let tr = line.translation {
                Text(tr)
                    .font(.system(size: isActive ? 14 : 13))
                    .foregroundStyle(isActive ? Color.accentColor.opacity(0.9) : Color.secondary.opacity(0.3))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
        }
        .padding(.vertical, isActive ? 16 : 10)
        .animation(.spring(response: 0.35, dampingFraction: 0.72), value: isActive)
    }
}

// ── カラオケエフェクト（Canvas ベース、スムーズなグラデーション）──
struct KaraokeTextView: View {
    let text: String
    let progress: Double  // 0.0 ~ 1.0
    let rhymeColorIndex: Int?
    let timedWords: [TimedWord]?  // 単語レベルのタイミング（オプション）

    var baseColor: Color {
        rhymeColorIndex.map { RhymeDetector.rhymeColor($0) } ?? .white
    }

    var body: some View {
        ZStack(alignment: .center) {
            // 背景：薄いグレー
            Text(text)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(Color.primary.opacity(0.15))
                .lineLimit(nil)
                .multilineTextAlignment(.center)

            // Canvas でのレンダリング
            if let timedWords = timedWords, !timedWords.isEmpty {
                // 単語ごとのタイミングがある場合：より正確
                TimedWordKaraokeView(
                    words: timedWords,
                    progress: progress,
                    color: baseColor
                )
            } else {
                // 単語ごとのタイミングがない場合：全体の進度に基づく
                SimpleKaraokeView(
                    text: text,
                    progress: progress,
                    color: baseColor
                )
            }
        }
        .frame(height: 60)
    }
}

// ── 単語ごとのタイミング情報がある場合（最高精度）──
struct TimedWordKaraokeView: View {
    let words: [TimedWord]
    let progress: Double
    let color: Color

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            HStack(spacing: 2) {
                ForEach(Array(words.enumerated()), id: \.offset) { _, word in
                    let totalDuration = (words.last?.timestamp ?? 0) + (words.last?.duration ?? 1)
                    let currentTime = progress * totalDuration
                    
                    var wordOpacity: Double = 0.15
                    if currentTime >= word.timestamp + word.duration {
                        wordOpacity = 1.0
                    } else if currentTime >= word.timestamp {
                        let elapsed = currentTime - word.timestamp
                        wordOpacity = 0.15 + (elapsed / word.duration) * 0.85
                    }
                    
                    Text(word.text)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(color)
                        .opacity(wordOpacity)
                        .animation(.linear(duration: 0.032), value: progress)
                }
                Spacer()
            }
            .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(height: 60)
    }
}

// ── 単語ごとのタイミングがない場合（シンプル版）──
struct SimpleKaraokeView: View {
    let text: String
    let progress: Double
    let color: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                // 背景テキスト（薄いグレー）
                Text(text)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Color.primary.opacity(0.15))
                    .lineLimit(nil)
                    .multilineTextAlignment(.center)
                    .frame(width: geo.size.width, alignment: .center)

                // カラーテキスト（マスク付き）
                Text(text)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(color)
                    .lineLimit(nil)
                    .multilineTextAlignment(.center)
                    .frame(width: geo.size.width, alignment: .center)
                    .mask(alignment: .topLeading) {
                        VStack(spacing: 0) {
                            HStack(spacing: 0) {
                                Rectangle()
                                    .frame(width: geo.size.width * progress)
                                Spacer()
                            }
                            Spacer()
                        }
                    }

                // グロー効果（スムーズなハイライト）
                if progress > 0.05 && progress < 0.95 {
                    Text(text)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(color.opacity(0.3))
                        .lineLimit(nil)
                        .multilineTextAlignment(.center)
                        .frame(width: geo.size.width, alignment: .center)
                        .blur(radius: 8)
                        .mask(alignment: .topLeading) {
                            VStack(spacing: 0) {
                                HStack(spacing: 0) {
                                    Rectangle()
                                        .frame(width: geo.size.width * progress)
                                    Spacer()
                                }
                                Spacer()
                            }
                        }
                        .allowsHitTesting(false)
                }
            }
        }
        .frame(height: 60)
    }
}

// ── 非アクティブ行（韻の色付き）──
struct RhymeAwareText: View {
    let text: String
    let isPast: Bool
    let rhymeColorIndex: Int?

    var opacity: Double { isPast ? 0.3 : 0.45 }

    var body: some View {
        if let colorIdx = rhymeColorIndex {
            // 末尾の有意な単語だけ韻の色でハイライト
            let trimmed = text.trimmingCharacters(in: .whitespaces)
            let words = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            
            if words.count >= 1 {
                let lastWord = words.last ?? ""
                let beforeLast = words.dropLast().joined(separator: " ")
                let rhymeColor = RhymeDetector.rhymeColor(colorIdx)
                
                if beforeLast.isEmpty {
                    // 1語のみ
                    Text(lastWord)
                        .font(.system(size: isPast ? 17 : 19, weight: isPast ? .regular : .medium))
                        .foregroundStyle(rhymeColor.opacity(isPast ? 0.5 : 0.8))
                        .multilineTextAlignment(.center)
                } else {
                    // 複数語
                    (Text(beforeLast + " ")
                        .foregroundStyle(Color.primary.opacity(opacity))
                    + Text(lastWord)
                        .foregroundStyle(rhymeColor.opacity(isPast ? 0.5 : 0.8))
                    )
                    .font(.system(size: isPast ? 17 : 19, weight: isPast ? .regular : .medium))
                    .multilineTextAlignment(.center)
                }
            } else {
                Text(text)
                    .font(.system(size: isPast ? 17 : 19, weight: isPast ? .regular : .medium))
                    .foregroundStyle(Color.primary.opacity(opacity))
                    .multilineTextAlignment(.center)
            }
        } else {
            Text(text)
                .font(.system(size: isPast ? 17 : 19, weight: isPast ? .regular : .medium))
                .foregroundStyle(Color.primary.opacity(opacity))
                .multilineTextAlignment(.center)
        }
    }
}
