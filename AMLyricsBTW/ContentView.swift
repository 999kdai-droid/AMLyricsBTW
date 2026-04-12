import SwiftUI
import Translation
import AVKit

@MainActor
struct ContentView: View {
    @StateObject private var nowPlaying = NowPlayingService()
    @State private var lyrics: [LyricLine] = []
    @State private var isLoadingLyrics = false
    @State private var showTranslation = false
    @State private var isTranslating = false
    @State private var lastFetchedTitle = ""
    @State private var translationConfig: TranslationSession.Configuration? = nil
    @State private var lyricsOffset: Double = 0.0
    @State private var showOffsetSlider = false
    @State private var autoScrollEnabled = true
    @State private var showRhymes = false
    @State private var albumTracks: [AlbumTrack] = []
    @State private var motionArtworkURL: URL? = nil
    @State private var staticArtworkImage: NSImage? = nil
    @State private var dominantColors: [Color] = [
        Color(red:0.2,green:0.1,blue:0.4),
        Color(red:0.1,green:0.1,blue:0.5),
        Color(red:0.15,green:0.05,blue:0.3)
    ]
    @State private var lyricsFontSize: CGFloat = 32

    private let fontSizes: [CGFloat] = [22, 32, 44]
    private var fontSizeLabel: String {
        switch lyricsFontSize {
        case 22: return "Aa₁"
        case 44: return "Aa₃"
        default: return "Aa₂"
        }
    }

    var body: some View {
        ZStack {
            // ── 背景：アルバムカラーのアンビエントグロー ──
            Color.black.ignoresSafeArea()
            GeometryReader { geo in
                ZStack {
                    Circle()
                        .fill(dominantColors[0])
                        .frame(width: 500, height: 500)
                        .blur(radius: 120)
                        .offset(x: -geo.size.width * 0.15, y: -geo.size.height * 0.2)
                    Circle()
                        .fill(dominantColors.count > 1 ? dominantColors[1] : dominantColors[0])
                        .frame(width: 400, height: 400)
                        .blur(radius: 100)
                        .offset(x: geo.size.width * 0.25, y: geo.size.height * 0.1)
                    Circle()
                        .fill(dominantColors.count > 2 ? dominantColors[2] : dominantColors[0])
                        .frame(width: 350, height: 350)
                        .blur(radius: 110)
                        .offset(x: 0, y: geo.size.height * 0.45)
                }
                .opacity(0.65)
            }
            .ignoresSafeArea()
            Color.black.opacity(0.35).ignoresSafeArea()

            VStack(spacing: 0) {
                // ── トップバー（ガラス）──
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(nowPlaying.currentTrack.title.isEmpty ? "再生していません" : nowPlaying.currentTrack.title)
                            .font(.headline).foregroundStyle(.white).lineLimit(1)
                        Text(nowPlaying.currentTrack.artist.isEmpty ? "Apple Musicを開いて再生してください" : nowPlaying.currentTrack.artist)
                            .font(.caption).foregroundStyle(Color.white.opacity(0.6)).lineLimit(1)
                    }
                    Spacer()

                    if showOffsetSlider {
                        HStack(spacing: 6) {
                            Button("-0.5") { lyricsOffset = max(lyricsOffset - 0.5, -5.0) }
                                .glassButton()
                            Slider(value: $lyricsOffset, in: -5.0...5.0, step: 0.1).frame(width: 80)
                            Button("+0.5") { lyricsOffset = min(lyricsOffset + 0.5, 5.0) }
                                .glassButton()
                            Button("R") { lyricsOffset = 0 }
                                .font(.caption).foregroundStyle(Color.accentColor)
                        }
                    }

                    // フォントサイズ
                    Button {
                        let idx = fontSizes.firstIndex(of: lyricsFontSize) ?? 1
                        lyricsFontSize = fontSizes[(idx + 1) % fontSizes.count]
                    } label: {
                        Text(fontSizeLabel)
                            .font(.system(size: 11, weight: .semibold))
                            .frame(width: 30, height: 30)
                            .background(Color.white.opacity(0.12))
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 0.5))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.white)

                    // ライムスキーム
                    Button { showRhymes.toggle() } label: {
                        Image(systemName: "music.quarternote.3")
                            .font(.caption).frame(width: 30, height: 30)
                            .background(showRhymes ? Color.purple : Color.white.opacity(0.12))
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 0.5))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.white)

                    // タイミング
                    Button { withAnimation(.spring(response: 0.3)) { showOffsetSlider.toggle() } } label: {
                        Image(systemName: "clock.fill")
                            .font(.caption).frame(width: 30, height: 30)
                            .background(showOffsetSlider ? Color.accentColor : Color.white.opacity(0.12))
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 0.5))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.white)

                    // 自動スクロール
                    Button { autoScrollEnabled.toggle() } label: {
                        Image(systemName: autoScrollEnabled ? "lock.fill" : "lock.slash.fill")
                            .font(.caption).frame(width: 30, height: 30)
                            .background(autoScrollEnabled ? Color.accentColor : Color.white.opacity(0.12))
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 0.5))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.white)

                    // 和訳
                    Button {
                        if !showTranslation {
                            showTranslation = true
                            if lyrics.allSatisfy({ $0.translation == nil }) { Task { await translateLyrics() } }
                        } else { showTranslation = false }
                    } label: {
                        Label(showTranslation ? "和訳ON" : "和訳", systemImage: "character.bubble")
                            .font(.caption)
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(showTranslation ? Color.accentColor : Color.white.opacity(0.12))
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 0.5))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.white)
                    .overlay { if isTranslating { ProgressView().scaleEffect(0.6) } }
                }
                .padding(.horizontal, 20).padding(.vertical, 12)
                .background(.ultraThinMaterial)
                .overlay(Rectangle().frame(height: 0.5).foregroundStyle(Color.white.opacity(0.1)), alignment: .bottom)

                // ── メインコンテンツ ──
                HStack(spacing: 0) {
                    // 左パネル（ガラス）
                    VStack(spacing: 14) {
                        // アルバムアート
                        MotionArtworkView(
                            videoURL: motionArtworkURL,
                            staticImage: staticArtworkImage,
                            title: nowPlaying.currentTrack.title,
                            artist: nowPlaying.currentTrack.artist,
                            album: nowPlaying.currentTrack.album
                        )

                        // 曲情報
                        VStack(spacing: 3) {
                            Text(nowPlaying.currentTrack.title)
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(.white)
                                .lineLimit(2).multilineTextAlignment(.center)
                            Text(nowPlaying.currentTrack.artist)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color.white.opacity(0.65))
                                .lineLimit(1)
                            if !nowPlaying.currentTrack.album.isEmpty {
                                Text(nowPlaying.currentTrack.album)
                                    .font(.system(size: 11))
                                    .foregroundStyle(Color.white.opacity(0.4))
                                    .lineLimit(1)
                            }
                        }

                        // 再生コントロール
                        HStack(spacing: 24) {
                            Button { nowPlaying.previousTrack() } label: {
                                Image(systemName: "backward.fill")
                                    .font(.system(size: 18))
                                    .foregroundStyle(Color.white.opacity(0.8))
                            }.buttonStyle(.plain)

                            Button { nowPlaying.togglePlayPause() } label: {
                                Image(systemName: nowPlaying.isPlaying ? "pause.fill" : "play.fill")
                                    .font(.system(size: 22))
                                    .foregroundStyle(.white)
                                    .frame(width: 52, height: 52)
                                    .background(.ultraThinMaterial)
                                    .clipShape(Circle())
                                    .overlay(Circle().stroke(Color.white.opacity(0.25), lineWidth: 0.5))
                            }.buttonStyle(.plain)

                            Button { nowPlaying.nextTrack() } label: {
                                Image(systemName: "forward.fill")
                                    .font(.system(size: 18))
                                    .foregroundStyle(Color.white.opacity(0.8))
                            }.buttonStyle(.plain)
                        }

                        // アルバム曲リスト
                        if !albumTracks.isEmpty {
                            VStack(alignment: .leading, spacing: 0) {
                                Text("アルバムの曲")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Color.white.opacity(0.5))
                                    .padding(.horizontal, 12).padding(.vertical, 8)

                                ScrollView(showsIndicators: false) {
                                    VStack(spacing: 0) {
                                        ForEach(Array(albumTracks.enumerated()), id: \.element.id) { idx, track in
                                            if idx == 0 || albumTracks[idx-1].discNumber != track.discNumber {
                                                Text("Disc \(track.discNumber)")
                                                    .font(.system(size: 10, weight: .semibold))
                                                    .foregroundStyle(Color.white.opacity(0.4))
                                                    .padding(.horizontal, 12).padding(.vertical, 6)
                                                    .frame(maxWidth: .infinity, alignment: .leading)
                                            }
                                            Button { nowPlaying.playTrack(named: track.name) } label: {
                                                HStack(spacing: 10) {
                                                    Text(String(format: "%02d", track.trackNumber))
                                                        .font(.system(size: 13, weight: .medium))
                                                        .foregroundStyle(Color.white.opacity(0.4))
                                                        .frame(width: 26)
                                                    Text(track.name)
                                                        .font(.system(size: 13))
                                                        .foregroundStyle(
                                                            track.name == nowPlaying.currentTrack.title
                                                            ? Color.accentColor : Color.white.opacity(0.8)
                                                        )
                                                        .lineLimit(1)
                                                    Spacer()
                                                }
                                                .padding(.horizontal, 12).padding(.vertical, 8)
                                            }
                                            .buttonStyle(.plain)
                                            if idx < albumTracks.count - 1 {
                                                Divider().opacity(0.1)
                                            }
                                        }
                                    }
                                }
                                .frame(maxHeight: 180)
                            }
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.12), lineWidth: 0.5))
                        }

                        Spacer()
                    }
                    .frame(width: 300)
                    .padding(20)

                    // 区切り線
                    Rectangle()
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 0.5)
                        .padding(.vertical, 16)

                    // 右パネル：歌詞
                    ZStack {
                        if isLoadingLyrics {
                            VStack(spacing: 12) {
                                ProgressView().tint(.white)
                                Text("歌詞を取得中...").font(.caption).foregroundStyle(Color.white.opacity(0.6))
                            }
                        } else if lyrics.isEmpty && !nowPlaying.currentTrack.title.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "text.bubble").font(.largeTitle).foregroundStyle(Color.white.opacity(0.3))
                                Text("歌詞が見つかりませんでした").font(.caption).foregroundStyle(Color.white.opacity(0.5))
                            }
                        } else if lyrics.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "music.note").font(.largeTitle).foregroundStyle(Color.white.opacity(0.3))
                                Text("曲を再生すると歌詞が表示されます").font(.caption).foregroundStyle(Color.white.opacity(0.5))
                            }
                        } else {
                            NewLyricsView(
                                lines: lyrics,
                                currentTime: nowPlaying.playerPosition,
                                showTranslation: showTranslation,
                                offset: lyricsOffset,
                                autoScrollEnabled: autoScrollEnabled,
                                showRhymes: showRhymes,
                                fontSize: lyricsFontSize,
                                nowPlayingService: nowPlaying
                            )
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.vertical, 16)
                }
            }
            .translationTask(translationConfig) { session in
                defer { translationConfig = nil; isTranslating = false }
                do {
                    let requests = lyrics.map {
                        TranslationSession.Request(sourceText: $0.text, clientIdentifier: $0.id.uuidString)
                    }
                    let responses = try await session.translations(from: requests)
                    for response in responses {
                        if let idx = lyrics.firstIndex(where: { $0.id.uuidString == response.clientIdentifier }) {
                            lyrics[idx].translation = response.targetText
                        }
                    }
                } catch { print("Translation error: \(error)") }
            }
        }
        .frame(minWidth: 900, minHeight: 650)
        .onAppear {
            nowPlaying.start()
            Task {
                try? await Task.sleep(nanoseconds: 500_000_000)
                let track = nowPlaying.currentTrack
                if !track.title.isEmpty {
                    await fetchAll(track: track)
                    albumTracks = await AlbumTracksService.fetchAlbumTracks(albumName: track.album, artist: track.artist)
                }
            }
        }
        .onDisappear { nowPlaying.stop() }
        .onChange(of: nowPlaying.currentTrack) { _, track in
            guard track.title != lastFetchedTitle, !track.title.isEmpty else { return }
            lastFetchedTitle = track.title
            Task {
                await fetchAll(track: track)
                albumTracks = await AlbumTracksService.fetchAlbumTracks(albumName: track.album, artist: track.artist)
            }
        }
    }

    func translateLyrics() async {
        guard !lyrics.isEmpty else { return }
        isTranslating = true
        let updated = await TranslationService.fetchTranslation(
            lines: lyrics, title: nowPlaying.currentTrack.title, artist: nowPlaying.currentTrack.artist
        )
        if updated.contains(where: { $0.translation != nil }) {
            lyrics = updated; isTranslating = false; return
        }
        translationConfig = TranslationSession.Configuration(
            source: Locale.Language(identifier: "en"),
            target: Locale.Language(identifier: "ja")
        )
    }

    func fetchAll(track: Track) async {
        isLoadingLyrics = true
        lyrics = []
        motionArtworkURL = nil
        async let lyricsResult = LRCLIBService.fetchLyrics(title: track.title, artist: track.artist)
        async let artworkResult = ArtworkService.fetchArtworkURL(title: track.title, artist: track.artist)
        async let motionResult = ArtworkService.fetchMotionArtworkURL(title: track.title, artist: track.artist, album: track.album)
        let (newLyrics, artURL, motionURL) = await (lyricsResult, artworkResult, motionResult)
        lyrics = newLyrics
        nowPlaying.currentTrack.artworkURL = artURL
        motionArtworkURL = motionURL
        if let artURL {
            if let (data, _) = try? await URLSession.shared.data(from: artURL),
               let img = NSImage(data: data) {
                staticArtworkImage = img
                // アルバムカラー抽出
                let extracted = ColorExtractor.extract(from: img, count: 3)
                withAnimation(.easeInOut(duration: 1.5)) { dominantColors = extracted }
            }
        }
        isLoadingLyrics = false
        if showTranslation { Task { await translateLyrics() } }
    }
}

// ── ガラスボタンスタイル ──
extension View {
    func glassButton() -> some View {
        self
            .font(.caption)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(Color.white.opacity(0.12))
            .foregroundStyle(.white)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 0.5))
            .buttonStyle(.plain)
    }
}

// ── アルバムアートビュー ──
struct MotionArtworkView: View {
    let videoURL: URL?
    let staticImage: NSImage?
    let title: String
    let artist: String
    let album: String
    @State private var player: AVPlayer?

    var body: some View {
        Group {
            if let player, videoURL != nil {
                VideoPlayer(player: player)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .frame(height: 260)
                    .shadow(color: .black.opacity(0.5), radius: 20)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.15), lineWidth: 0.5))
                    .onAppear { player.play() }
                    .onDisappear { player.pause() }
            } else if let img = staticImage {
                Image(nsImage: img)
                    .resizable().scaledToFill()
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .frame(height: 260)
                    .shadow(color: .black.opacity(0.5), radius: 20)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.15), lineWidth: 0.5))
            } else {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.06))
                    .frame(height: 260)
                    .overlay(Image(systemName: "music.note").font(.system(size: 44)).foregroundStyle(Color.white.opacity(0.3)))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.1), lineWidth: 0.5))
            }
        }
        .onAppear { loadVideo() }
        .onChange(of: videoURL) { _, _ in loadVideo() }
    }

    private func loadVideo() {
        guard let url = videoURL else { player = nil; return }
        let item = AVPlayerItem(url: url)
        let p = AVPlayer(playerItem: item)
        p.actionAtItemEnd = .none
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main
        ) { _ in p.seek(to: .zero); p.play() }
        player = p
    }
}
