# Minecraft Development Environment Template

Krz-Tech Minecraft Server Project の Coder 開発環境テンプレートです。

## 🚀 クイックスタート

### 1. Coder ワークスペースの作成

Coder ダッシュボードから `mc-develop-container` テンプレートでワークスペースを作成します。

### 2. Minecraft サーバーの管理

統合スクリプト `mc` を使用：

```bash
cd ~/minecraft-project-coder_template

# セットアップ (Paper + Skript ダウンロード)
./scripts/mc setup

# サーバー起動
./scripts/mc start

# 外部公開付きで起動 (playit.gg)
./scripts/mc start --tunnel

# サーバー停止
./scripts/mc stop

# 状態確認 (接続URL表示)
./scripts/mc status

# ログ表示
./scripts/mc logs
```

---

## 🌐 外部からのアクセス (playit.gg)

開発サーバーに外部から接続したい場合は、playit.gg を使用します。

### 初回セットアップ

```bash
# トンネル付きで起動
./scripts/start-minecraft-server.sh --tunnel
```

1. **playit.gg にログイン**: ターミナルに表示されるリンクをブラウザで開く
2. **トンネルを追加**: ダッシュボードで `Add Tunnel` → `Minecraft Java` → `Local port: 25566`
3. **接続**: 発行されたアドレス（例: `xxx.at.playit.gg`）で Minecraft から接続

---

## 📁 ディレクトリ構造

```
minecraft-project-coder_template/
├── minecraft-project/           # ドキュメント (Git submodule)
│   └── Docs/
├── minecraft-server/            # Minecraft サーバー (gitignore)
│   ├── paper.jar
│   ├── plugins/
│   │   ├── Skript-*.jar
│   │   └── Skript/
│   │       └── scripts/         # ← Skript 開発対象
│   └── logs/
├── scripts/
│   ├── setup-minecraft-server.sh
│   ├── start-minecraft-server.sh
│   ├── stop-minecraft-server.sh
│   └── init-workspace.sh
└── develop-container/           # Coder テンプレート
    └── coder/
        ├── Dockerfile
        └── main.tf
```

---

## 🛠️ 利用可能なコマンド

### 統合スクリプト (./scripts/mc)

| コマンド | 説明 |
|-----------|------|
| `mc setup` | Paper JAR と Skript をダウンロード |
| `mc start` | サーバー起動 |
| `mc start --tunnel` | 外部公開付きで起動 |
| `mc stop` | サーバー停止 |
| `mc restart` | サーバー再起動 |
| `mc status` | サーバー状態・接続URL表示 |
| `mc logs` | ログ表示 (tail -f) |

### 個別スクリプト

| スクリプト | 説明 |
|-----------|------|
| `setup-minecraft-server.sh` | Paper JAR と Skript をダウンロード |
| `start-minecraft-server.sh` | サーバー起動 |
| `stop-minecraft-server.sh` | サーバー停止 |
| `status-minecraft-server.sh` | サーバー状態・接続URL表示 |
| `init-workspace.sh` | Git submodule 更新・環境チェック |

### オプション一覧

#### setup-minecraft-server.sh

```bash
--version <VER>    # Minecraft バージョン指定 (例: 1.21.4)
--build <NUM>      # Paper ビルド番号指定
```

#### start-minecraft-server.sh

```bash
--memory <SIZE>    # メモリ指定 (例: 2G, 4G)
--foreground, -f   # フォアグラウンドで起動
--tunnel, -t       # playit.gg で外部公開
--port <PORT>      # サーバーポート指定 (デフォルト: 25566)
```

#### stop-minecraft-server.sh

```bash
--force, -f        # 強制停止 (SIGKILL)
--timeout <SEC>    # 停止タイムアウト秒数
```

---

## 🔧 Skript 開発

Skript ファイルの編集場所：

```
minecraft-server/plugins/Skript/scripts/
```

### ホットリロード

サーバー内で以下のコマンドを実行：

```
/skript reload <スクリプト名>
```

または全スクリプトをリロード：

```
/skript reload all
```

---

## 📊 ポート一覧

| ポート | 用途 |
|-------|------|
| 25566 | Minecraft サーバー (開発用) |
| 25575 | RCON |

---

## 🔗 関連ドキュメント

- [プロジェクト概要](minecraft-project/README.md)
- [ゲームシステム設計](minecraft-project/Docs/GameSystem/)
- [技術アーキテクチャ](minecraft-project/Docs/TechArchitecture.md)

---

## 📝 ライセンス

Krz-Tech Minecraft Server Project
