import SwiftUI

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
                            ? Dictionary(uniqueKeysWithValues:
                                (0..<words.count).compactMap { wi -> (Int, Int)? in
                                    guard let c = rhymeMap["\(i)_\(wi)"] else { return nil }
                                    return (wi, c)
                                })
                            : [:]

                        VStack(alignment: .center, spacing: 5) {
                            NewKaraokeText(
                                words: words,
                                wordRhymes: wordRhymes,
                                progress: progress,
                                fontSize: fontSize
                            )
                            if showTranslation, let tr = line.translation, !tr.isEmpty {
                                Text(tr)
                                    .font(.system(size: max(fontSize * 0.45, 13), weight: .regular))
                                    .foregroundStyle(isActive ? Color.accentColor.opacity(0.95) : Color.white.opacity(0.35))
                                    .multilineTextAlignment(.center)
                                    .lineLimit(3)
                                    .animation(.easeOut(duration: 0.3), value: isActive)
                            }
                        }
                        .padding(.horizontal, 16)
                        .scaleEffect(isActive ? 1.0 : 0.95, anchor: .center)
                        .opacity(isActive ? 1.0 : (isPast ? 0.45 : 0.2))
                        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isActive)
                        .onTapGesture { nowPlayingService.setPlayerPosition(line.timestamp) }
                        .id(i)
                    }
                    Spacer().frame(height: 60)
                }
            }
            .onChange(of: activeIndex) { _, idx in
                if autoScrollEnabled {
                    proxy.scrollTo(idx, anchor: .center)
                    withAnimation(.easeOut(duration: 0.2)) {
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

struct NewKaraokeText: View {
    let words: [String]
    let wordRhymes: [Int: Int]
    let progress: Double
    let fontSize: CGFloat

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                StyledWordText(words: words, wordRhymes: wordRhymes, opacity: 0.18, fontSize: fontSize)
                    .multilineTextAlignment(.center)
                    .frame(width: geo.size.width, alignment: .center)

                StyledWordText(words: words, wordRhymes: wordRhymes, opacity: 1.0, fontSize: fontSize)
                    .multilineTextAlignment(.center)
                    .frame(width: geo.size.width, alignment: .center)
                    .mask(
                        LinearGradient(
                            stops: [
                                .init(color: .white, location: max(0, progress - 0.08)),
                                .init(color: .white.opacity(0.98), location: max(0, progress - 0.02)),
                                .init(color: .clear, location: min(1, progress + 0.02)),
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .shadow(color: Color.white.opacity(progress > 0.02 ? 0.45 : 0), radius: 10)
            }
        }
        .frame(minHeight: fontSize * 2.2)
    }
}

struct StyledWordText: View {
    let words: [String]
    let wordRhymes: [Int: Int]
    let opacity: Double
    let fontSize: CGFloat

    var body: some View {
        words.enumerated().reduce(Text("")) { acc, pair in
            let (i, word) = pair
            let suffix = i == words.count - 1 ? "" : " "
            let base = Text(word + suffix).font(.system(size: fontSize, weight: .bold))
            if let c = wordRhymes[i] {
                return acc + base.foregroundStyle(
                    RhymeDetector.rhymeColor(c).opacity(opacity == 1.0 ? 1.0 : min(opacity * 3, 0.55))
                )
            }
            return acc + base.foregroundStyle(Color.white.opacity(opacity))
        }
    }
}
