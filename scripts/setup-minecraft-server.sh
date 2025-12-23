#!/bin/bash
# =============================================================================
# setup-minecraft-server.sh
# Minecraft Paper サーバー初回セットアップスクリプト
# 
# 使用方法 / Usage:
#   ./scripts/setup-minecraft-server.sh [--version <MC_VERSION>] [--build <BUILD_NUMBER>]
#
# 例 / Examples:
#   ./scripts/setup-minecraft-server.sh                    # 最新安定版
#   ./scripts/setup-minecraft-server.sh --version 1.21.4   # 特定バージョン
# =============================================================================

set -euo pipefail

# -----------------------------------------------------------------------------
# 定数 / Constants
# -----------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
SERVER_DIR="${PROJECT_ROOT}/minecraft-server"
PAPER_API_URL="https://api.papermc.io/v2"

# デフォルト設定 / Default Settings
DEFAULT_MC_VERSION="1.21.4"
MC_VERSION="${DEFAULT_MC_VERSION}"
BUILD_NUMBER=""

# Aikar's Flags (パフォーマンス最適化)
AIKARS_FLAGS="-XX:+UseG1GC -XX:+ParallelRefProcEnabled -XX:MaxGCPauseMillis=200 -XX:+UnlockExperimentalVMOptions -XX:+DisableExplicitGC -XX:+AlwaysPreTouch -XX:G1NewSizePercent=30 -XX:G1MaxNewSizePercent=40 -XX:G1HeapRegionSize=8M -XX:G1ReservePercent=20 -XX:G1HeapWastePercent=5 -XX:G1MixedGCCountTarget=4 -XX:InitiatingHeapOccupancyPercent=15 -XX:G1MixedGCLiveThresholdPercent=90 -XX:G1RSetUpdatingPauseTimePercent=5 -XX:SurvivorRatio=32 -XX:+PerfDisableSharedMem -XX:MaxTenuringThreshold=1 -Dusing.aikars.flags=https://mcflags.emc.gs -Daikars.new.flags=true"

# -----------------------------------------------------------------------------
# カラー出力 / Colored Output
# -----------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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
    exit 1
}

# -----------------------------------------------------------------------------
# 引数パース / Argument Parsing
# -----------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
    case $1 in
        --version)
            MC_VERSION="$2"
            shift 2
            ;;
        --build)
            BUILD_NUMBER="$2"
            shift 2
            ;;
        --help)
            echo "使用方法: $0 [--version <MC_VERSION>] [--build <BUILD_NUMBER>]"
            echo ""
            echo "オプション:"
            echo "  --version   Minecraft バージョン (例: 1.21.4)"
            echo "  --build     Paper ビルド番号 (省略時は最新)"
            exit 0
            ;;
        *)
            log_error "不明なオプション: $1"
            ;;
    esac
done

# -----------------------------------------------------------------------------
# 依存関係チェック / Dependency Check
# -----------------------------------------------------------------------------
check_dependencies() {
    log_info "依存関係をチェック中..."
    
    local missing=()
    
    if ! command -v java &> /dev/null; then
        missing+=("java")
    else
        local java_version
        java_version=$(java -version 2>&1 | head -n 1 | cut -d'"' -f2 | cut -d'.' -f1)
        if [[ "$java_version" -lt 21 ]]; then
            log_warn "Java 21+ が推奨されます (現在: Java $java_version)"
        fi
    fi
    
    if ! command -v curl &> /dev/null; then
        missing+=("curl")
    fi
    
    if ! command -v jq &> /dev/null; then
        missing+=("jq")
    fi
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "以下のツールがインストールされていません: ${missing[*]}"
    fi
    
    log_success "依存関係チェック完了"
}

# -----------------------------------------------------------------------------
# Paper JAR ダウンロード / Download Paper JAR
# -----------------------------------------------------------------------------
download_paper() {
    log_info "Paper JAR をダウンロード中 (MC ${MC_VERSION})..."
    
    # ビルド番号が指定されていない場合、最新を取得
    if [[ -z "$BUILD_NUMBER" ]]; then
        log_info "最新ビルド番号を取得中..."
        BUILD_NUMBER=$(curl -s "${PAPER_API_URL}/projects/paper/versions/${MC_VERSION}/builds" \
            | jq -r '.builds | map(select(.channel == "default")) | last | .build')
        
        if [[ "$BUILD_NUMBER" == "null" || -z "$BUILD_NUMBER" ]]; then
            log_error "ビルド番号の取得に失敗しました。バージョン ${MC_VERSION} が存在するか確認してください。"
        fi
    fi
    
    log_info "ビルド番号: ${BUILD_NUMBER}"
    
    # ダウンロード名を取得
    local download_name
    download_name=$(curl -s "${PAPER_API_URL}/projects/paper/versions/${MC_VERSION}/builds/${BUILD_NUMBER}" \
        | jq -r '.downloads.application.name')
    
    if [[ "$download_name" == "null" || -z "$download_name" ]]; then
        log_error "ダウンロード情報の取得に失敗しました。"
    fi
    
    # ダウンロード
    local download_url="${PAPER_API_URL}/projects/paper/versions/${MC_VERSION}/builds/${BUILD_NUMBER}/downloads/${download_name}"
    curl -L -o "${SERVER_DIR}/paper.jar" "$download_url"
    
    log_success "Paper JAR ダウンロード完了: ${download_name}"
}

# -----------------------------------------------------------------------------
# ディレクトリ構造作成 / Create Directory Structure
# -----------------------------------------------------------------------------
create_directories() {
    log_info "ディレクトリ構造を作成中..."
    
    mkdir -p "${SERVER_DIR}/plugins/Skript/scripts"
    mkdir -p "${SERVER_DIR}/logs"
    mkdir -p "${SERVER_DIR}/world"
    
    log_success "ディレクトリ作成完了"
}

# -----------------------------------------------------------------------------
# Skript プラグインダウンロード / Download Skript Plugin
# -----------------------------------------------------------------------------
download_skript() {
    log_info "Skript プラグインをダウンロード中..."
    
    local github_api="https://api.github.com/repos/SkriptLang/Skript/releases/latest"
    
    # 最新リリース情報を取得
    local release_info
    release_info=$(curl -s "$github_api")
    
    if [[ -z "$release_info" ]]; then
        log_warn "Skript リリース情報の取得に失敗しました。スキップします。"
        return 1
    fi
    
    # バージョンとダウンロードURLを抽出
    local version
    local download_url
    version=$(echo "$release_info" | jq -r '.tag_name')
    download_url=$(echo "$release_info" | jq -r '.assets[0].browser_download_url')
    
    if [[ "$version" == "null" || "$download_url" == "null" ]]; then
        log_warn "Skript ダウンロード情報の解析に失敗しました。スキップします。"
        return 1
    fi
    
    local jar_name
    jar_name=$(echo "$release_info" | jq -r '.assets[0].name')
    
    log_info "Skript バージョン: ${version}"
    
    # ダウンロード
    if curl -L -o "${SERVER_DIR}/plugins/${jar_name}" "$download_url"; then
        log_success "Skript ダウンロード完了: ${jar_name}"
    else
        log_warn "Skript のダウンロードに失敗しました。"
        return 1
    fi
}

# -----------------------------------------------------------------------------
# 設定ファイル生成 / Generate Configuration Files
# -----------------------------------------------------------------------------
generate_configs() {
    log_info "設定ファイルを生成中..."
    
    # EULA 同意 (開発環境用)
    echo "eula=true" > "${SERVER_DIR}/eula.txt"
    log_info "eula.txt 作成完了"
    
    # server.properties
    cat > "${SERVER_DIR}/server.properties" << 'EOF'
# =============================================================================
# Minecraft Server Properties (開発環境用 / Development Environment)
# =============================================================================

# ネットワーク設定 / Network
server-port=25566
server-ip=
enable-query=false
enable-rcon=true
rcon.password=dev_rcon_password
rcon.port=25575

# 認証設定 / Authentication
online-mode=false
enforce-secure-profile=false

# ワールド設定 / World
level-name=world
level-type=minecraft\:normal
generate-structures=true
max-world-size=29999984
spawn-protection=0

# ゲーム設定 / Gameplay
gamemode=survival
difficulty=normal
pvp=true
allow-flight=true
max-players=10

# パフォーマンス / Performance
view-distance=10
simulation-distance=10
max-tick-time=60000

# その他 / Misc
motd=\u00A7b[DEV] \u00A7fKrz-Tech Minecraft Dev Server
white-list=false
enforce-whitelist=false
EOF
    
    log_success "server.properties 作成完了"
    
    # 起動スクリプト設定ファイル
    cat > "${SERVER_DIR}/start.conf" << EOF
# サーバー起動設定
MEMORY_MIN=1G
MEMORY_MAX=2G
EXTRA_FLAGS="${AIKARS_FLAGS}"
EOF
    
    log_info "start.conf 作成完了"
}

# -----------------------------------------------------------------------------
# メイン / Main
# -----------------------------------------------------------------------------
main() {
    echo ""
    echo "=========================================="
    echo "  Minecraft Paper Server Setup Script"
    echo "  Target: MC ${MC_VERSION}"
    echo "=========================================="
    echo ""
    
    check_dependencies
    
    if [[ -f "${SERVER_DIR}/paper.jar" ]]; then
        log_warn "既存の paper.jar が検出されました。上書きしますか? (y/N)"
        read -r response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            log_info "セットアップをスキップします。"
            exit 0
        fi
    fi
    
    create_directories
    download_paper
    download_skript
    generate_configs
    
    echo ""
    log_success "=========================================="
    log_success "  セットアップ完了!"
    log_success "=========================================="
    echo ""
    echo "次のステップ:"
    echo "  1. サーバー起動: ./scripts/start-minecraft-server.sh"
    echo "  2. プラグイン追加: ${SERVER_DIR}/plugins/ に配置"
    echo "  3. Skript 開発: ${SERVER_DIR}/plugins/Skript/scripts/"
    echo ""
}

main "$@"
