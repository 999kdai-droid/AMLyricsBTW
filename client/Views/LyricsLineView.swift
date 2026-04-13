import SwiftUI

// MARK: - Lyrics Line View (Line Highlight Mode)
struct LyricsLineView: View {
    let line: LyricsLine
    let isActive: Bool
    let currentTime: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Original lyrics
            Text(line.text)
                .font(.system(size: 24, weight: isActive ? .bold : .regular))
                .foregroundStyle(isActive ? .white : .secondary)
                .scaleEffect(isActive ? 1.05 : 1.0)
            
            // Translation
            if !line.translation.isEmpty {
                Text(line.translation)
                    .font(.system(size: 18, weight: isActive ? .medium : .regular))
                    .foregroundStyle(isActive ? .white.opacity(0.8) : .secondary.opacity(0.6))
                    .scaleEffect(isActive ? 1.05 : 1.0)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.vertical, 8)
        .opacity(isActive ? 1.0 : 0.4)
        .animation(.easeInOut(duration: 0.2), value: isActive)
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
        
        VStack(spacing: 20) {
            LyricsLineView(
                line: LyricsLine.mockWithoutWords,
                isActive: false,
                currentTime: 0.0
            )
            
            LyricsLineView(
                line: LyricsLine.mockWithoutWords,
                isActive: true,
                currentTime: 1.5
            )
        }
        .padding()
    }
}
