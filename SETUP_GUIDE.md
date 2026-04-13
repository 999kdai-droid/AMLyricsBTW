# AMLyricsBTW セットアップガイド

このプロジェクトは2台のマシンで動作します：
- **サーバー (iMac 2015)**: Python/FastAPIサーバー、WhisperX解析
- **クライアント (このMac)**: SwiftUIアプリ、Xcode

---

## 🖥 サーバー (iMac 2015) で実行するコマンド

iMac 2015で以下の手順を実行してください。

### 1. プロジェクトのクローン

```bash
cd ~/Desktop  # または任意の場所
git clone https://github.com/999kdai-droid/AMLyricsBTW.git
cd iMusic/server
```

### 2. Python仮想環境の作成と依存パッケージのインストール

```bash
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt
```

### 3. ffmpegのインストール

```bash
brew install ffmpeg
```

（Homebrewがインストールされていない場合: `bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"`）

### 4. 環境変数ファイルの作成

```bash
cp .env.example .env
nano .env  # または vim .env
```

`.env` ファイルを編集して以下を設定：
```
AMLYRICS_API_KEY=your_secure_api_key_here
GEMINI_API_KEY=your_gemini_api_key_here
WHISPER_MODEL=medium
```

### 5. キャッシュディレクトリの作成

```bash
mkdir -p cache
```

### 6. サーバーの起動

```bash
source venv/bin/activate
python main.py
```

サーバーが `http://0.0.0.0:8000` で起動します。

### 7. 固定IPの設定

iMacのネットワーク設定で固定IPを設定してください（例: `192.168.1.100`）

---

## 💻 クライアント (このMac) で実行するコマンド

このMacで以下の手順を実行してください。

### 1. プロジェクトのクローン

```bash
cd ~/Developer
git clone https://github.com/999kdai-droid/AMLyricsBTW.git
cd iMusic
```

### 2. Xcodeプロジェクトの作成

Xcodeを開いて以下の手順でプロジェクトを作成します：

1. **新しいプロジェクトの作成**
   - Xcodeを開く
   - File → New → Project
   - macOS → App を選択
   - Product Name: `AMLyricsBTW`
   - Interface: SwiftUI
   - Language: Swift
   - Storage: SwiftData
   - 保存場所: `~/Developer/iMusic/`

2. **プロジェクト設定**
   - Deployment Target: macOS 15.0
   - Swift Language Version: Swift 6
   - Bundle Identifier: `com.example.amlyricsbtw`

3. **Capabilitiesの追加**
   - Target → Signing & Capabilities
   - + Capability → MusicKit
   - + Capability → App Sandbox（必要な場合）

4. **Info.plistの編集**
   - Target → Infoタブ
   - Key: `NSAppleMusicUsageDescription`
   - Value: `This app needs access to Apple Music to display synchronized lyrics.`

### 3. Swiftファイルの追加

Xcodeプロジェクトに `client/` ディレクトリ内のファイルを追加します：

```bash
# Xcodeプロジェクトを開いた状態で、以下のファイルをドラッグ＆ドロップ
# またはXcode内で右クリック → Add Files to "AMLyricsBTW"

client/Models/LyricsModels.swift
client/Views/LyricsView.swift
client/Views/KaraokeLineView.swift
client/Views/LyricsLineView.swift
client/Views/OffsetAdjustView.swift
client/Managers/LyricProvider.swift
client/Managers/SyncClock.swift
client/Managers/ServerClient.swift
client/SwiftData/CachedLyrics.swift
client/Utilities/ColorExtractor.swift
```

**重要**: ファイル追加時に「Copy items if needed」にチェックを入れてください。

### 4. サーバー設定の追加

アプリ内でサーバー設定を行う必要があります。設定画面を作成するか、UserDefaults経由で設定します：

```swift
// アプリ起動時に一度だけ実行
UserDefaults.standard.set("http://192.168.1.100:8000", forKey: "serverBaseURL")
UserDefaults.standard.set("your_api_key_here", forKey: "serverAPIKey")
```

または、設定画面を作成してユーザーに入力させます。

### 5. ビルドと実行

Xcodeで ⌘R を押してビルド・実行します。

---

## 🌐 GitHubへの同期

### リポジトリの作成（GitHub上）

1. GitHubで新しいリポジトリを作成: https://github.com/new
2. リポジトリ名: `AMLyricsBTW`
3. PublicまたはPrivateを選択

### Gitコマンドの実行（このMacで）

```bash
cd ~/Developer/iMusic

# .gitignoreの作成（まだの場合）
cat > .gitignore << 'EOF'
# Python
server/venv/
server/__pycache__/
server/*.pyc
server/.env
server/cache/

# macOS
.DS_Store
*.dmg

# Xcode
xcode_project/
*.xcodeproj/
*.xcworkspace/
DerivedData/

# Swift
*.swiftpm/
.build/

# Temporary files
*.tmp
*.log
EOF

# Git初期化
git init
git add .
git commit -m "Initial commit: AMLyricsBTW implementation"

# GitHubリモート追加
git branch -M main
git remote add origin https://github.com/999kdai-droid/AMLyricsBTW.git
git push -u origin main
```

### GitHub CLIを使用する場合（インストール済みの場合）

```bash
cd ~/Developer/iMusic
gh repo create AMLyricsBTW --public --source=. --remote=origin
git branch -M main
git push -u origin main
```

---

## 📋 セットアップチェックリスト

### サーバー (iMac 2015)
- [ ] Python 3.11+ インストール済み
- [ ] ffmpeg インストール済み
- [ ] 仮想環境作成済み
- [ ] 依存パッケージインストール済み
- [ ] .envファイル作成・編集済み
- [ ] キャッシュディレクトリ作成済み
- [ ] 固定IP設定済み
- [ ] サーバー起動確認済み

### クライアント (このMac)
- [ ] Xcodeインストール済み
- [ ] Xcodeプロジェクト作成済み
- [ ] Swiftファイル追加済み
- [ ] MusicKit有効化済み
- [ ] SwiftData有効化済み
- [ ] サーバーURL・APIキー設定済み
- [ ] ビルド成功確認済み

### GitHub
- [ ] GitHubリポジトリ作成済み
- [ ] .gitignore作成済み
- [ ] Git初期化済み
- [ ] 最初のコミット済み
- [ ] GitHubにプッシュ済み

---

## 🔧 トラブルシューティング

### サーバーが起動しない
```bash
# ポート8000が使用されている場合
lsof -ti:8000 | xargs kill -9

# 依存パッケージの再インストール
pip install -r requirements.txt --force-reinstall
```

### WhisperXモデルのダウンロードに失敗
- 初回起動時にモデルがダウンロードされます。インターネット接続を確認してください。
- モデルは `~/.cache/whisper/` に保存されます。

### クライアントでサーバーに接続できない
- iMacとクライアントが同じLAN内にあることを確認
- ファイアウォール設定でポート8000を許可
- `.env` のAPIキーが一致していることを確認

---

## 📝 補足

- サーバーはバックグラウンドで実行することをお勧め（`nohup python main.py > server.log 2>&1 &`）
- 定期的にキャッシュのクリーンアップを行ってください（`CachedLyrics.cleanupOldCache()`）
- WhisperXの解析時間はmediumモデルで5〜8分/曲です
