# Minecraft Development Environment Template

Krz-Tech Minecraft Server Project の Coder 開発環境テンプレートです。

## 🚀 クイックスタート

```bash
cd ~/minecraft-project-coder_template

# 1. セットアップ
./mc setup

# 2. サーバー起動
./mc start

# 3. ローカルマシンで接続
coder port-forward <workspace-name> --tcp 25565:25566

# 4. Minecraft クライアントで localhost:25565 に接続
```

## 📋 コマンド一覧

```bash
./mc setup   # Paper + Skript ダウンロード
./mc start   # サーバー起動
./mc stop    # サーバー停止
./mc restart # 再起動
./mc status  # 状態確認
./mc logs    # ログ表示
```

## 🔌 接続方法

サーバー起動後、**ローカルマシン**で以下を実行:

```bash
coder port-forward <workspace-name> --tcp 25565:25566
```

Minecraft クライアントで `localhost:25565` に接続。

## 📁 ディレクトリ構造

```
minecraft-project-coder_template/
├── mc                           # 管理スクリプト
├── minecraft-server/            # サーバーデータ (gitignore)
│   ├── paper.jar
│   ├── plugins/Skript/scripts/  # ← Skript 開発
│   └── logs/
└── develop-container/coder/     # Coder テンプレート
```

## 🔧 Skript 開発

編集: `minecraft-server/plugins/Skript/scripts/`

リロード: サーバー内で `/skript reload all`

## 📊 ポート

| ポート | 用途 |
|-------|------|
| 25566 | Minecraft サーバー |
