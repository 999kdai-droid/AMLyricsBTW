import SwiftUI

// ── 音節カウント ──
private func syllableCount(_ word: String) -> Double {
    let w = word.lowercased().replacingOccurrences(of: #"[^a-z]"#, with: "", options: .regularExpression)
    let vowels: Set<Character> = ["a","e","i","o","u","y"]
    var count = 0; var prev = false
    for ch in w { let v = vowels.contains(ch); if v && !prev { count += 1 }; prev = v }
    if w.hasSuffix("e") && count > 1 { count -= 1 }
    return max(1.0, Double(count))
}

// ── 単語タイミング推定（行全体の0.0〜1.0内での各単語の開始・終了）──
private func estimateWordTimings(_ words: [String]) -> [(start: Double, end: Double)] {
    guard !words.isEmpty else { return [] }
    let weights = words.map { syllableCount($0) }
    let total = weights.reduce(0, +)
    var result: [(Double, Double)] = []
    var cursor = 0.0
    for w in weights {
        let duration = w / total
        result.append((cursor, cursor + duration))
        cursor += duration
    }
    return result
}

struct NewLyricsView: View {
    let lines: [LyricLine]
    let currentTime: Double
    let showTranslation: Bool
    let offset: Double
    let autoScrollEnabled: Bool
    let showRhymes: Bool
    let fontSize: CGFloat
    let nowPlayingService: NowPlayingService

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
        return next < lines.count ? lines[next].timestamp : (lines.last?.timestamp ?? 0) + 5.0
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(alignment: .center, spacing: 6) {
                    Spacer().frame(height: 60)
                    ForEach(Array(lines.enumerated()), id: \.element.id) { i, line in
                        let isActive = i == activeIndex
                        let isPast   = i < activeIndex
                        let lineEnd  = isActive ? nextTimestamp : line.timestamp
                        let progress = isActive
                            ? calcProgress(adjustedTime, line.timestamp, lineEnd)
                            : (isPast ? 1.0 : 0.0)
                        let words = line.text.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                        let wordRhymes: [Int: Int] = showRhymes
                            ? Dictionary(uniqueKeysWithValues: (0..<words.count).compactMap { wi -> (Int,Int)? in
                                guard let c = rhymeMap["\(i)_\(wi)"] else { return nil }
                                return (wi, c) })
                            : [:]

                        VStack(alignment: .center, spacing: 5) {
                            WordRevealText(
                                words: words,
                                wordRhymes: wordRhymes,
                                progress: progress,
                                fontSize: isActive ? fontSize : max(fontSize * 0.82, 16),
                                isActive: isActive
                            )
                            if showTranslation, let tr = line.translation, !tr.isEmpty {
                                Text(tr)
                                    .font(.system(size: max(fontSize * 0.42, 13), weight: .regular))
                                    .foregroundStyle(isActive ? Color.accentColor.opacity(0.95) : Color.white.opacity(0.3))
                                    .multilineTextAlignment(.center)
                                    .lineLimit(3)
                            }
                        }
                        .padding(.horizontal, 16)
                        .opacity(isActive ? 1.0 : (isPast ? 0.45 : 0.18))
                        .animation(.spring(response: 0.32, dampingFraction: 0.78), value: isActive)
                        .onTapGesture { nowPlayingService.setPlayerPosition(line.timestamp) }
                        .id(i)
                    }
                    Spacer().frame(height: 60)
                }
            }
            .onChange(of: activeIndex) { _, idx in
                if autoScrollEnabled {
                    proxy.scrollTo(idx, anchor: .center)
                    withAnimation(.easeOut(duration: 0.18)) {
                        proxy.scrollTo(idx, anchor: .center)
                    }
                }
            }
        }
        .onAppear { rhymeMap = RhymeDetector.detectRhymes(in: lines) }
        .onChange(of: lines.count) { _, _ in rhymeMap = RhymeDetector.detectRhymes(in: lines) }
    }

    private func calcProgress(_ t: Double, _ start: Double, _ end: Double) -> Double {
        let dur = end - start
        guard dur > 0 else { return 0 }
        return max(0, min(1, (t - start) / dur))
    }
}

// ── 単語ごとに光るビュー ──
struct WordRevealText: View {
    let words: [String]
    let wordRhymes: [Int: Int]
    let progress: Double
    let fontSize: CGFloat
    let isActive: Bool

    private var timings: [(start: Double, end: Double)] { estimateWordTimings(words) }

    var body: some View {
        LyricFlowLayout(spacing: 5, lineSpacing: 4) {
            ForEach(Array(words.enumerated()), id: \.offset) { i, word in
                let timing = i < timings.count ? timings[i] : (0.0, 1.0)
                // 各単語のローカル進捗（少し先読みして自然に）
                let raw = (progress - timing.start) / max(timing.end - timing.start, 0.01)
                let clipped = max(0.0, min(1.0, raw))
                // Cubic ease-in-out
                let eased = clipped < 0.5
                    ? 4 * clipped * clipped * clipped
                    : 1 - pow(-2 * clipped + 2, 3) / 2
                let rhymeColor: Color = wordRhymes[i].map { RhymeDetector.rhymeColor($0) } ?? .white

                ZStack {
                    // ベース（薄く常時表示）
                    Text(word)
                        .font(.system(size: fontSize, weight: .bold))
                        .foregroundStyle(rhymeColor.opacity(wordRhymes[i] != nil ? 0.35 : 0.18))

                    // 前景（eased進捗でフェードイン）
                    Text(word)
                        .font(.system(size: fontSize, weight: .bold))
                        .foregroundStyle(rhymeColor)
                        .opacity(eased)
                        .scaleEffect(1.0 + eased * 0.05, anchor: .bottom)
                        .shadow(color: rhymeColor.opacity(eased * 0.7), radius: eased * 10)
                        .shadow(color: rhymeColor.opacity(eased * 0.3), radius: eased * 20)
                }
                .animation(.interpolatingSpring(stiffness: 280, damping: 22), value: eased)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// ── 折り返しレイアウト ──
struct LyricFlowLayout: Layout {
    var spacing: CGFloat = 5
    var lineSpacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        layout(proposal: proposal, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(proposal: ProposedViewSize(bounds.size), subviews: subviews)
        for (i, frame) in result.frames.enumerated() {
            subviews[i].place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                proposal: ProposedViewSize(frame.size)
            )
        }
    }

    private func layout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, frames: [CGRect]) {
        let maxW = proposal.width ?? 400
        var frames = [CGRect](repeating: .zero, count: subviews.count)
        var rowItems: [(Int, CGSize)] = []
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0

        func commitRow() {
            let totalW = rowItems.map{$0.1.width}.reduce(0,+) + spacing * CGFloat(max(rowItems.count-1, 0))
            let ox = max((maxW - totalW) / 2, 0)
            var rx = ox
            for (idx, sz) in rowItems {
                frames[idx] = CGRect(x: rx, y: y, width: sz.width, height: sz.height)
                rx += sz.width + spacing
            }
            y += rowH + lineSpacing; rowH = 0; rowItems = []; x = 0
        }

        for (i, sv) in subviews.enumerated() {
            let sz = sv.sizeThatFits(ProposedViewSize(width: maxW, height: nil))
            if x + sz.width > maxW && !rowItems.isEmpty { commitRow() }
            rowItems.append((i, sz)); x += sz.width + spacing; rowH = max(rowH, sz.height)
        }
        if !rowItems.isEmpty { commitRow() }
        return (CGSize(width: maxW, height: max(y - lineSpacing, 0)), frames)
    }
}
