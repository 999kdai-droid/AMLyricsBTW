# APIキー設定ガイド

AMLyricsBTWで必要なAPIキーと設定場所について説明します。

---

## 🖥 サーバー側 (iMac 2015) で必要なAPIキー

### 1. Gemini APIキー (必須)

**用途**: 歌詞の日本語意訳

**入手方法**:
1. [Google AI Studio](https://aistudio.google.com/) にアクセス
2. Googleアカウントでログイン
3. 「APIキーを取得」をクリック
4. APIキーをコピー

**設定場所**: `server/.env` ファイル

```bash
cd ~/Desktop/iMusic/server
cp .env.example .env
nano .env  # または vim .env
```

`.env` ファイルに以下を追加:
```
GEMINI_API_KEY=your_gemini_api_key_here
```

### 2. AMLyricsBTW APIキー (必須)

**用途**: クライアント-サーバー間通信の認証

**入手方法**:
- 自分で任意の文字列を決める（例: ランダムな文字列）
- セキュリティのため、十分に長く複雑な文字列にすること

**設定場所**: `server/.env` ファイル

`.env` ファイルに以下を追加:
```
AMLYRICS_API_KEY=your_secure_random_key_here
```

**推奨**: ランダム文字列生成ツールを使用
```bash
# macOSの場合
openssl rand -hex 32
```

### 3. WhisperXモデル設定 (オプション)

**用途**: WhisperXのモデルサイズ選択

**設定場所**: `server/.env` ファイル

```
WHISPER_MODEL=medium  # "small" または "medium"
```

- `medium`: 高精度、解析時間5〜8分/曲（推奨）
- `small`: 低精度、解析時間2〜4分/曲

---

## 💻 クライアント側 (このMac) で必要な設定

### 1. サーバーベースURL (必須)

**用途**: iMacサーバーのアドレス

**設定場所**: アプリ内のUserDefaults

```swift
UserDefaults.standard.set("http://192.168.1.100:8000", forKey: "serverBaseURL")
```

または、設定画面を作成してユーザーに入力させる。

### 2. サーバーAPIキー (必須)

**用途**: サーバーへのリクエスト認証

**設定場所**: アプリ内のUserDefaults

```swift
UserDefaults.standard.set("your_secure_random_key_here", forKey: "serverAPIKey")
```

**注意**: サーバーの `.env` で設定した `AMLYRICS_API_KEY` と同じ値を使用すること。

---

## 🔧 設定手順

### サーバー側 (iMac 2015)

```bash
# 1. .envファイルを作成
cd ~/Desktop/iMusic/server
cp .env.example .env

# 2. .envを編集
nano .env

# 以下の内容を設定:
# GEMINI_API_KEY=your_gemini_api_key_here
# AMLYRICS_API_KEY=your_secure_random_key_here
# WHISPER_MODEL=medium

# 3. 保存してエディタを終了 (nanoの場合: Ctrl+O, Enter, Ctrl+X)
```

### クライアント側 (このMac)

Xcodeプロジェクトで設定画面を作成するか、アプリ起動時に以下のコードを追加:

```swift
import SwiftUI

@main
struct AMLyricsBTWApp: App {
    init() {
        // サーバー設定（開発用）
        UserDefaults.standard.register(defaults: [
            "serverBaseURL": "http://192.168.1.100:8000",
            "serverAPIKey": "your_secure_random_key_here"
        ])
    }
    
    var body: some Scene {
        // ...
    }
}
```

または、設定画面を作成してユーザーに入力させることを推奨。

---

## 📋 設定チェックリスト

### サーバー側
- [ ] Gemini APIキーを取得
- [ ] AMLyricsBTW APIキーを生成
- [ ] server/.envファイルを作成
- [ ] .envにGEMINI_API_KEYを設定
- [ ] .envにAMLYRICS_API_KEYを設定
- [ ] .envにWHISPER_MODELを設定

### クライアント側
- [ ] サーバーベースURLを設定 (192.168.1.100:8000)
- [ ] サーバーAPIキーを設定 (サーバーと同じ値)
- [ ] 設定画面を作成 (推奨)

---

## 🔒 セキュリティ注意点

1. **`.env` ファイルは絶対にGitHubにコミットしない**
   - `.gitignore` に含まれていますが、確認してください
   - 誤ってコミットした場合は、APIキーを無効化して再生成してください

2. **APIキーは安全に管理**
   - パスワードマネージャーに保存
   - 他の人と共有しない

3. **LAN内でのみ使用**
   - この設定はLAN内通信のみ想定
   - インターネット公開はセキュリティ上推奨しません

---

## 📝 設定例

### server/.env 例
```
AMLYRICS_API_KEY=a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6
GEMINI_API_KEY=AIzaSyABC123XYZ456DEF789GHI012JKL345MNO
WHISPER_MODEL=medium
```

### クライアント側設定例
```swift
UserDefaults.standard.set("http://192.168.1.100:8000", forKey: "serverBaseURL")
UserDefaults.standard.set("a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6", forKey: "serverAPIKey")
```

---

## 🆘 トラブルシューティング

### Gemini APIが動作しない
- APIキーが正しいか確認
- Google AI StudioでAPIキーが有効か確認
- クォータ制限に達していないか確認

### クライアントがサーバーに接続できない
- サーバーとクライアントのAPIキーが一致しているか確認
- サーバーのIPアドレスが正しいか確認
- ファイアウォールでポート8000が許可されているか確認

### APIキーを忘れた場合
- Gemini API: Google AI Studioで再生成
- AMLyricsBTW APIキー: 新しく生成して、サーバーとクライアントの両方を更新
