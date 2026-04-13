# AMLyricsBTW

Apple Musicで再生中の曲に対し、自前サーバー（iMac 2015）での高精度WhisperX解析とGemini APIによる日本語意訳を組み合わせた、macOS専用の同期歌詞表示アプリ。

## プロジェクト構成

```
iMusic/
├── server/              # Python/FastAPIサーバー
│   ├── main.py         # FastAPIアプリ本体
│   ├── config.py       # 設定管理
│   ├── queue_manager.py # ジョブキューマネージャー
│   ├── analyzer.py     # WhisperX解析+ffmpeg無音検知
│   ├── translator.py   # Gemini API翻訳
│   ├── cache.py        # キャッシュ管理
│   ├── requirements.txt
│   ├── .env.example
│   └── gemini_system_prompt.txt
└── client/              # SwiftUIクライアント
    ├── Models/
    │   └── LyricsModels.swift
    ├── Views/
    │   ├── LyricsView.swift
    │   ├── KaraokeLineView.swift
    │   ├── LyricsLineView.swift
    │   └── OffsetAdjustView.swift
    ├── Managers/
    │   ├── LyricProvider.swift
    │   ├── SyncClock.swift
    │   └── ServerClient.swift
    ├── SwiftData/
    │   └── CachedLyrics.swift
    └── Utilities/
        └── ColorExtractor.swift
```

## サーバー側セットアップ

### 1. 依存パッケージのインストール

```bash
cd server
python -m venv venv
source venv/bin/activate  # macOS/Linux
pip install -r requirements.txt
```

### 2. 環境変数の設定

`.env.example` を `.env` にコピーして設定:

```bash
cp .env.example .env
```

`.env` ファイルを編集して以下を設定:
- `AMLYRICS_API_KEY`: クライアント-サーバー間通信用のAPIキー
- `GEMINI_API_KEY`: Gemini APIキー
- `WHISPER_MODEL`: `small` または `medium` (デフォルト: medium)

### 3. 必要なツールのインストール

- **ffmpeg**: 音声処理用
  ```bash
  brew install ffmpeg
  ```

- **yt-dlp**: YouTube音源取得用 (requirements.txtに含まれています)

### 4. サーバーの起動

```bash
python -m uvicorn main:app --host 0.0.0.0 --port 8000
```

または:

```bash
python main.py
```

### 5. 固定IPの設定

iMacのネットワーク設定で固定IPを設定してください (例: 192.168.1.100)

## クライアント側セットアップ

### 1. Xcodeプロジェクトの作成

- Xcodeで新しいmacOS Appプロジェクトを作成
- Swift 6, macOS 15.0+ をターゲットに設定
- SwiftDataを有効化
- MusicKitを有効化 (Info.plistに `NSAppleMusicUsageDescription` を追加)

### 2. ファイルの追加

`client/` ディレクトリ内のファイルをXcodeプロジェクトに追加

### 3. サーバー設定

アプリの設定画面で以下を設定:
- サーバーベースURL: `http://192.168.1.100:8000` (iMacのIP)
- APIキー: サーバーの `.env` で設定したもの

## APIエンドポイント

### POST /analyze
新しい曲の解析をリクエスト

```json
{
  "track_id": "apple_music_track_id",
  "title": "曲タイトル",
  "artist": "アーティスト名",
  "is_favorite": false
}
```

### GET /status/{job_id}
ジョブの状態を取得

### GET /cache/{track_id}
キャッシュされた歌詞を取得

### GET /queue
現在のキュー状態を取得

## 機能

### サーバー側
- WhisperXによる高精度音声認識 (CPU専用)
- ffmpegによる無音検知とオフセット補正
- Gemini APIによる日本語意訳
- ジョブキューシステムによる順次処理
- JSONキャッシュによる再利用

### クライアント側
- お気に入り曲: 単語レベルのカラオケ塗りつぶしアニメーション
- 通常曲: 行単位のハイライト表示
- アートワークから抽出したDominant Colorによる動的背景
- ±0.1s単位の手動オフセット補正
- SwiftDataによるローカルキャッシュ
- Spotify-Lyric-APIによるフォールバック

## 注意事項

- iMac 2015はGPU非搭載のため、WhisperXはCPUのみで動作します
- mediumモデルの解析時間: 5〜8分/曲 (CPU動作時)
- smallモデルに切り替えると2〜4分/曲まで短縮可能ですが、精度が低下します
- LAN内通信のみ対応 (インターネット公開は非推奨)

## ライセンス

MIT License
