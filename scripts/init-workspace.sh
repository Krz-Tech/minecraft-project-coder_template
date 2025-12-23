#!/bin/bash
# =============================================================================
# init-workspace.sh
# Coder ワークスペース初期化スクリプト
# 
# このスクリプトは Coder ワークスペース起動時に自動実行されることを想定しています。
# - Git submodule の初期化・更新
# - 開発環境の依存関係チェック
# - オプション: Minecraft サーバーの自動セットアップ
#
# 使用方法 / Usage:
#   ./scripts/init-workspace.sh [--auto-setup]
# =============================================================================

set -euo pipefail

# -----------------------------------------------------------------------------
# 定数 / Constants
# -----------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

AUTO_SETUP=false

# -----------------------------------------------------------------------------
# カラー出力 / Colored Output
# -----------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_header() {
    echo -e "${CYAN}$1${NC}"
}

# -----------------------------------------------------------------------------
# 引数パース / Argument Parsing
# -----------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
    case $1 in
        --auto-setup)
            AUTO_SETUP=true
            shift
            ;;
        --help)
            echo "使用方法: $0 [オプション]"
            echo ""
            echo "オプション:"
            echo "  --auto-setup    Minecraft サーバーを自動セットアップ"
            echo "  --help          ヘルプを表示"
            exit 0
            ;;
        *)
            shift
            ;;
    esac
done

# -----------------------------------------------------------------------------
# Git Submodule 更新 / Update Git Submodules
# -----------------------------------------------------------------------------
update_submodules() {
    log_header "=========================================="
    log_header "  Git Submodule 更新"
    log_header "=========================================="
    echo ""
    
    cd "$PROJECT_ROOT"
    
    if [[ -f ".gitmodules" ]]; then
        log_info "Submodule を初期化・更新中..."
        git submodule update --init --recursive
        log_success "Submodule 更新完了"
    else
        log_info "Submodule は設定されていません"
    fi
    
    echo ""
}

# -----------------------------------------------------------------------------
# 開発環境チェック / Check Development Environment
# -----------------------------------------------------------------------------
check_dev_environment() {
    log_header "=========================================="
    log_header "  開発環境チェック"
    log_header "=========================================="
    echo ""
    
    local all_ok=true
    
    # Java
    if command -v java &> /dev/null; then
        local java_version
        java_version=$(java -version 2>&1 | head -n 1)
        log_success "Java: $java_version"
    else
        log_warn "Java: 未インストール (Minecraft サーバー起動に必要)"
        all_ok=false
    fi
    
    # Git
    if command -v git &> /dev/null; then
        local git_version
        git_version=$(git --version)
        log_success "Git: $git_version"
    else
        log_error "Git: 未インストール"
        all_ok=false
    fi
    
    # curl
    if command -v curl &> /dev/null; then
        log_success "curl: インストール済"
    else
        log_warn "curl: 未インストール (Paper ダウンロードに必要)"
        all_ok=false
    fi
    
    # jq
    if command -v jq &> /dev/null; then
        log_success "jq: インストール済"
    else
        log_warn "jq: 未インストール (Paper ダウンロードに必要)"
        all_ok=false
    fi
    
    # mcrcon (オプション)
    if command -v mcrcon &> /dev/null; then
        log_success "mcrcon: インストール済 (RCON 管理可能)"
    else
        log_info "mcrcon: 未インストール (オプション - RCON 管理用)"
    fi
    
    echo ""
    
    if [[ "$all_ok" == true ]]; then
        log_success "すべての必須ツールが利用可能です"
    else
        log_warn "一部のツールが不足しています。上記を確認してください。"
    fi
    
    echo ""
}

# -----------------------------------------------------------------------------
# Minecraft サーバー状態確認 / Check Minecraft Server Status
# -----------------------------------------------------------------------------
check_minecraft_server() {
    log_header "=========================================="
    log_header "  Minecraft サーバー状態"
    log_header "=========================================="
    echo ""
    
    local server_dir="${PROJECT_ROOT}/minecraft-server"
    
    if [[ -f "${server_dir}/paper.jar" ]]; then
        log_success "Paper JAR: 存在します"
        
        # バージョン情報取得を試行
        if [[ -f "${server_dir}/version_history.json" ]]; then
            local version
            version=$(jq -r '.currentVersion' "${server_dir}/version_history.json" 2>/dev/null || echo "不明")
            log_info "バージョン: $version"
        fi
        
        # PID 確認
        if [[ -f "${server_dir}/server.pid" ]]; then
            local pid
            pid=$(cat "${server_dir}/server.pid")
            if kill -0 "$pid" 2>/dev/null; then
                log_success "サーバーステータス: 起動中 (PID: $pid)"
            else
                log_info "サーバーステータス: 停止中 (古い PID ファイルあり)"
            fi
        else
            log_info "サーバーステータス: 停止中"
        fi
    else
        log_info "Paper JAR: 未セットアップ"
        echo ""
        echo "  セットアップするには:"
        echo "    ./scripts/setup-minecraft-server.sh"
        
        if [[ "$AUTO_SETUP" == true ]]; then
            echo ""
            log_info "自動セットアップを実行します..."
            "${SCRIPT_DIR}/setup-minecraft-server.sh"
        fi
    fi
    
    echo ""
}

# -----------------------------------------------------------------------------
# 完了メッセージ / Completion Message
# -----------------------------------------------------------------------------
show_completion() {
    log_header "=========================================="
    log_header "  ワークスペース初期化完了"
    log_header "=========================================="
    echo ""
    echo "利用可能なコマンド:"
    echo ""
    echo "  # Minecraft サーバー"
    echo "  ./scripts/setup-minecraft-server.sh   # 初回セットアップ"
    echo "  ./scripts/start-minecraft-server.sh   # サーバー起動"
    echo "  ./scripts/stop-minecraft-server.sh    # サーバー停止"
    echo ""
    echo "  # ドキュメント"
    echo "  cat minecraft-project/Docs/Agent/GEMINI.md"
    echo "  cat minecraft-project/Docs/Agent/SKRIPT.md"
    echo ""
    echo "開発を始めましょう! 🚀"
    echo ""
}

# -----------------------------------------------------------------------------
# メイン / Main
# -----------------------------------------------------------------------------
main() {
    echo ""
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║  Krz-Tech Minecraft Project - Workspace Initialization       ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""
    
    update_submodules
    check_dev_environment
    check_minecraft_server
    show_completion
}

main "$@"
