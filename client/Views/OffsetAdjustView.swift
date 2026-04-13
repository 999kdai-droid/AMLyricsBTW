import SwiftUI

// MARK: - Offset Adjustment View
struct OffsetAdjustView: View {
    @AppStorage("lyricsOffset") private var offset: Double = 0.0
    @State private var stepperValue: Int = 0
    
    var body: some View {
        HStack(spacing: 12) {
            Button(action: { adjustOffset(-0.1) }) {
                Image(systemName: "minus.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            
            Text(offsetText)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.primary)
                .frame(minWidth: 60)
            
            Button(action: { adjustOffset(0.1) }) {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            
            Button(action: resetOffset) {
                Text("Reset")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .onAppear {
            stepperValue = Int(offset * 10)
        }
    }
    
    private var offsetText: String {
        let sign = offset >= 0 ? "+" : ""
        return String(format: "\(sign)%.1fs", offset)
    }
    
    private func adjustOffset(_ delta: Double) {
        offset += delta
        offset = round(offset * 10) / 10  // Round to 0.1
    }
    
    private func resetOffset() {
        offset = 0.0
    }
}

// MARK: - Preview
#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        
        VStack {
            Spacer()
            OffsetAdjustView()
                .padding()
        }
    }
}
