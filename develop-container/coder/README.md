# Minecraft Development Container for Coder

Krz-Tech Minecraft Server Project の開発環境テンプレートです。

## 含まれるツール

- **Java 21** (OpenJDK) - Minecraft Paper サーバー実行用
- **Git, curl, wget, jq** - セットアップスクリプト用
- **screen** - バックグラウンド実行用
- **Docker** - DinD 対応

## Minecraft サーバーへのアクセス方法

### 1. Coder Desktop (推奨)
[Coder Desktop](https://coder.com/docs/user-guides/desktop) をインストールすると、以下のアドレスで直接接続できます：

```
<workspace-name>.coder:25565
```

### 2. coder port-forward コマンド
ローカルマシンから以下のコマンドを実行：

```bash
coder port-forward <workspace-name> --tcp 25565:25565
```

その後、Minecraft クライアントで `localhost:25565` に接続。

### 3. SSH ポートフォワーディング

```bash
ssh -L 25565:localhost:25565 coder.<workspace-name>
```

### 4. Cloudflare Tunnel (外部公開用)
本番環境ではなく外部から開発サーバーにアクセスしたい場合は、
Cloudflare Tunnel を別途設定してください。

## クイックスタート

```bash
# 1. Minecraft サーバーセットアップ
cd ~/minecraft-project-coder_template
./scripts/setup-minecraft-server.sh

# 2. サーバー起動
./scripts/start-minecraft-server.sh

# 3. サーバー停止
./scripts/stop-minecraft-server.sh
```

## ポート一覧

| ポート | 用途 |
|-------|------|
| 25565 | Minecraft サーバー (開発用: 25566) |
| 25575 | RCON |