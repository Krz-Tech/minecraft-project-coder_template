#!/bin/bash
# =============================================================================
# start-minecraft-server.sh
# Minecraft Paper サーバー起動スクリプト
# 
# 使用方法 / Usage:
#   ./scripts/start-minecraft-server.sh [--memory <SIZE>] [--foreground]
#
# 例 / Examples:
#   ./scripts/start-minecraft-server.sh                    # バックグラウンド起動
#   ./scripts/start-minecraft-server.sh --foreground       # フォアグラウンド起動
#   ./scripts/start-minecraft-server.sh --memory 4G        # メモリ指定
# =============================================================================

set -euo pipefail

# -----------------------------------------------------------------------------
# 定数 / Constants
# -----------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
SERVER_DIR="${PROJECT_ROOT}/minecraft-server"
PID_FILE="${SERVER_DIR}/server.pid"
JAR_FILE="${SERVER_DIR}/paper.jar"
CONF_FILE="${SERVER_DIR}/start.conf"

# デフォルト設定 / Default Settings
MEMORY_MIN="1G"
MEMORY_MAX="2G"
FOREGROUND=false
EXTRA_FLAGS=""

# Aikar's Flags (デフォルト)
AIKARS_FLAGS="-XX:+UseG1GC -XX:+ParallelRefProcEnabled -XX:MaxGCPauseMillis=200 -XX:+UnlockExperimentalVMOptions -XX:+DisableExplicitGC -XX:+AlwaysPreTouch -XX:G1NewSizePercent=30 -XX:G1MaxNewSizePercent=40 -XX:G1HeapRegionSize=8M -XX:G1ReservePercent=20 -XX:G1HeapWastePercent=5 -XX:G1MixedGCCountTarget=4 -XX:InitiatingHeapOccupancyPercent=15 -XX:G1MixedGCLiveThresholdPercent=90 -XX:G1RSetUpdatingPauseTimePercent=5 -XX:SurvivorRatio=32 -XX:+PerfDisableSharedMem -XX:MaxTenuringThreshold=1"

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
# 設定ファイル読み込み / Load Configuration
# -----------------------------------------------------------------------------
load_config() {
    if [[ -f "$CONF_FILE" ]]; then
        log_info "設定ファイルを読み込み中: ${CONF_FILE}"
        # shellcheck source=/dev/null
        source "$CONF_FILE"
    fi
}

# -----------------------------------------------------------------------------
# 引数パース / Argument Parsing
# -----------------------------------------------------------------------------
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --memory)
                MEMORY_MAX="$2"
                MEMORY_MIN="$2"
                shift 2
                ;;
            --min-memory)
                MEMORY_MIN="$2"
                shift 2
                ;;
            --max-memory)
                MEMORY_MAX="$2"
                shift 2
                ;;
            --foreground|-f)
                FOREGROUND=true
                shift
                ;;
            --help)
                echo "使用方法: $0 [オプション]"
                echo ""
                echo "オプション:"
                echo "  --memory <SIZE>       メモリ設定 (例: 2G, 4G)"
                echo "  --min-memory <SIZE>   最小メモリ"
                echo "  --max-memory <SIZE>   最大メモリ"
                echo "  --foreground, -f      フォアグラウンドで起動"
                echo "  --help                ヘルプを表示"
                exit 0
                ;;
            *)
                log_error "不明なオプション: $1"
                ;;
        esac
    done
}

# -----------------------------------------------------------------------------
# 前提条件チェック / Prerequisites Check
# -----------------------------------------------------------------------------
check_prerequisites() {
    log_info "前提条件をチェック中..."
    
    # JAR ファイル存在確認
    if [[ ! -f "$JAR_FILE" ]]; then
        log_error "paper.jar が見つかりません。先に setup-minecraft-server.sh を実行してください。"
    fi
    
    # EULA 確認
    if [[ ! -f "${SERVER_DIR}/eula.txt" ]]; then
        log_error "eula.txt が見つかりません。先に setup-minecraft-server.sh を実行してください。"
    fi
    
    # 多重起動チェック
    if [[ -f "$PID_FILE" ]]; then
        local pid
        pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            log_error "サーバーは既に起動しています (PID: $pid)"
        else
            log_warn "古い PID ファイルを削除します"
            rm -f "$PID_FILE"
        fi
    fi
    
    log_success "前提条件チェック完了"
}

# -----------------------------------------------------------------------------
# サーバー起動 / Start Server
# -----------------------------------------------------------------------------
start_server() {
    log_info "Minecraft サーバーを起動中..."
    log_info "メモリ: ${MEMORY_MIN} - ${MEMORY_MAX}"
    
    cd "$SERVER_DIR"
    
    local java_cmd="java -Xms${MEMORY_MIN} -Xmx${MEMORY_MAX} ${AIKARS_FLAGS} ${EXTRA_FLAGS} -jar paper.jar --nogui"
    
    if [[ "$FOREGROUND" == true ]]; then
        log_info "フォアグラウンドモードで起動します (Ctrl+C で停止)"
        echo ""
        exec $java_cmd
    else
        log_info "バックグラウンドモードで起動します"
        nohup $java_cmd > "${SERVER_DIR}/logs/latest.log" 2>&1 &
        local pid=$!
        echo "$pid" > "$PID_FILE"
        
        # 起動確認 (数秒待機)
        sleep 3
        if kill -0 "$pid" 2>/dev/null; then
            log_success "サーバー起動成功 (PID: $pid)"
            echo ""
            echo "ログ確認:  tail -f ${SERVER_DIR}/logs/latest.log"
            echo "サーバー停止: ./scripts/stop-minecraft-server.sh"
        else
            log_error "サーバーの起動に失敗しました。ログを確認してください。"
        fi
    fi
}

# -----------------------------------------------------------------------------
# メイン / Main
# -----------------------------------------------------------------------------
main() {
    echo ""
    echo "=========================================="
    echo "  Minecraft Paper Server Launcher"
    echo "=========================================="
    echo ""
    
    load_config
    parse_args "$@"
    check_prerequisites
    start_server
}

main "$@"
