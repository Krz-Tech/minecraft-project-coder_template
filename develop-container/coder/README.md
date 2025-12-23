# Minecraft Development Container for Coder

Krz-Tech Minecraft Server Project の開発環境テンプレートです。

## 含まれるツール

- **Java 21** (OpenJDK) - Minecraft Paper サーバー実行用
- **Git, curl, wget, jq** - セットアップスクリプト用
- **screen** - バックグラウンド実行用
- **playit.gg** - TCP トンネリング（外部公開用）
- **Docker** - DinD 対応

## クイックスタート

```bash
# 1. Minecraft サーバーセットアップ
cd ~/minecraft-project-coder_template
./scripts/setup-minecraft-server.sh

# 2. サーバー起動
./scripts/start-minecraft-server.sh

# 3. 外部公開する場合 (playit.gg)
./scripts/start-minecraft-server.sh --tunnel

# 4. サーバー停止
./scripts/stop-minecraft-server.sh
```

## 外部からのアクセス方法 (playit.gg)

`--tunnel` オプションを使うと、playit.gg 経由で外部から接続可能になります。

### 初回セットアップ

1. `./scripts/start-minecraft-server.sh --tunnel` を実行
2. 別ターミナルで `playit` を実行
3. 表示されるリンクをブラウザで開き、playit.gg にログイン
4. ダッシュボードでトンネルを追加:
   - **Add Tunnel** → **Minecraft Java**
   - **Local port**: `25566`
5. 発行されたアドレス（例: `xxx.at.playit.gg`）で接続可能

### なぜ playit.gg？

- **TCP 対応**: Minecraft は TCP プロトコルを使用
- **無料**: 基本機能は無料で利用可能
- **ポート転送不要**: NAT/ファイアウォール越えが可能

## ポート一覧

| ポート | 用途 |
|-------|------|
| 25566 | Minecraft サーバー (開発用) |
| 25575 | RCON |