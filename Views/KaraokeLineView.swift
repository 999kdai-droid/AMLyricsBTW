import SwiftUI

// MARK: - Karaoke Line View (Word-Level Highlighting)
struct KaraokeLineView: View {
    let line: LyricsLine
    let currentTime: Double
    let isActive: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Original lyrics with karaoke effect
            karaokeTextLayer
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Translation
            if !line.translation.isEmpty {
                Text(line.translation)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(isActive ? .white.opacity(0.8) : .secondary.opacity(0.6))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.vertical, 8)
        .opacity(isActive ? 1.0 : 0.4)
    }
    
    private var karaokeTextLayer: some View {
        ZStack(alignment: .leading) {
            // Background layer (gray, unplayed)
            HStack(spacing: 4) {
                ForEach(Array(line.words?.enumerated() ?? [].enumerated()), id: \.offset) { _, word in
                    Text(word.word)
                        .font(.system(size: 24, weight: .regular))
                        .foregroundStyle(.secondary)
                }
            }
            
            // Foreground layer (white/accent, played) with clipping
            HStack(spacing: 4) {
                ForEach(Array(line.words?.enumerated() ?? [].enumerated()), id: \.offset) { index, word in
                    Text(word.word)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.white)
                        .mask(
                            GeometryReader { geometry in
                                let progress = wordProgress(for: word)
                                Rectangle()
                                    .fill(.white)
                                    .frame(width: geometry.size.width * progress)
                            }
                        )
                }
            }
        }
    }
    
    private func wordProgress(for word: WordTimestamp) -> Double {
        guard isActive else { return 0.0 }
        
        if currentTime < word.start {
            return 0.0
        } else if currentTime > word.end {
            return 1.0
        } else {
            let duration = word.end - word.start
            guard duration > 0 else { return 1.0 }
            return (currentTime - word.start) / duration
        }
    }
}

// MARK: - Preview
#Preview {
    ZStack {
        LinearGradient(
            colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.3)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
        
        VStack(spacing: 30) {
            // Not active
            KaraokeLineView(
                line: TrackLyrics.mock.lyrics[0],
                currentTime: 0.0,
                isActive: false
            )
            
            // Active, partially played
            KaraokeLineView(
                line: TrackLyrics.mock.lyrics[0],
                currentTime: 13.0,
                isActive: true
            )
            
            // Active, fully played
            KaraokeLineView(
                line: TrackLyrics.mock.lyrics[0],
                currentTime: 15.0,
                isActive: true
            )
        }
        .padding()
    }
}
