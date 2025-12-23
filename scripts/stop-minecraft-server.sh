#!/bin/bash
# =============================================================================
# stop-minecraft-server.sh
# Minecraft Paper サーバー停止スクリプト
# 
# 使用方法 / Usage:
#   ./scripts/stop-minecraft-server.sh [--force]
#
# 例 / Examples:
#   ./scripts/stop-minecraft-server.sh            # 通常停止 (RCON or SIGTERM)
#   ./scripts/stop-minecraft-server.sh --force    # 強制停止 (SIGKILL)
# =============================================================================

set -euo pipefail

# -----------------------------------------------------------------------------
# 定数 / Constants
# -----------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
SERVER_DIR="${PROJECT_ROOT}/minecraft-server"
PID_FILE="${SERVER_DIR}/server.pid"
PROPERTIES_FILE="${SERVER_DIR}/server.properties"

# デフォルト設定 / Default Settings
FORCE=false
RCON_PORT=25575
RCON_PASSWORD="dev_rcon_password"
SHUTDOWN_TIMEOUT=30

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
        --force|-f)
            FORCE=true
            shift
            ;;
        --timeout)
            SHUTDOWN_TIMEOUT="$2"
            shift 2
            ;;
        --help)
            echo "使用方法: $0 [オプション]"
            echo ""
            echo "オプション:"
            echo "  --force, -f        強制停止 (SIGKILL)"
            echo "  --timeout <SEC>    停止タイムアウト秒数 (デフォルト: 30)"
            echo "  --help             ヘルプを表示"
            exit 0
            ;;
        *)
            log_error "不明なオプション: $1"
            ;;
    esac
done

# -----------------------------------------------------------------------------
# RCON 設定読み込み / Load RCON Settings
# -----------------------------------------------------------------------------
load_rcon_settings() {
    if [[ -f "$PROPERTIES_FILE" ]]; then
        local port
        local password
        port=$(grep "^rcon.port=" "$PROPERTIES_FILE" | cut -d'=' -f2 | tr -d '\r')
        password=$(grep "^rcon.password=" "$PROPERTIES_FILE" | cut -d'=' -f2 | tr -d '\r')
        
        [[ -n "$port" ]] && RCON_PORT="$port"
        [[ -n "$password" ]] && RCON_PASSWORD="$password"
    fi
}

# -----------------------------------------------------------------------------
# RCON で停止 / Stop via RCON
# -----------------------------------------------------------------------------
stop_via_rcon() {
    if command -v mcrcon &> /dev/null; then
        log_info "RCON 経由で停止を試行します..."
        if mcrcon -H localhost -P "$RCON_PORT" -p "$RCON_PASSWORD" "stop" 2>/dev/null; then
            return 0
        fi
    fi
    return 1
}

# -----------------------------------------------------------------------------
# PID で停止 / Stop via PID
# -----------------------------------------------------------------------------
stop_via_pid() {
    if [[ ! -f "$PID_FILE" ]]; then
        log_error "PID ファイルが見つかりません。サーバーが起動していないか、手動で起動されました。"
    fi
    
    local pid
    pid=$(cat "$PID_FILE")
    
    if ! kill -0 "$pid" 2>/dev/null; then
        log_warn "プロセス (PID: $pid) は既に停止しています"
        rm -f "$PID_FILE"
        exit 0
    fi
    
    if [[ "$FORCE" == true ]]; then
        log_warn "強制停止します (SIGKILL)..."
        kill -9 "$pid" 2>/dev/null || true
    else
        log_info "サーバーを停止します (PID: $pid)..."
        kill -15 "$pid" 2>/dev/null || true
        
        # 停止待機
        local elapsed=0
        while kill -0 "$pid" 2>/dev/null; do
            if [[ $elapsed -ge $SHUTDOWN_TIMEOUT ]]; then
                log_warn "タイムアウト。強制停止します..."
                kill -9 "$pid" 2>/dev/null || true
                break
            fi
            sleep 1
            ((elapsed++))
            printf "\r[INFO] 停止待機中... %d/%d 秒" "$elapsed" "$SHUTDOWN_TIMEOUT"
        done
        echo ""
    fi
    
    rm -f "$PID_FILE"
    log_success "サーバー停止完了"
}

# -----------------------------------------------------------------------------
# メイン / Main
# -----------------------------------------------------------------------------
main() {
    echo ""
    echo "=========================================="
    echo "  Minecraft Paper Server Shutdown"
    echo "=========================================="
    echo ""
    
    load_rcon_settings
    
    # まず RCON を試行、失敗したら PID で停止
    if ! stop_via_rcon; then
        log_info "RCON 停止失敗。PID 経由で停止します..."
        stop_via_pid
    else
        log_success "RCON 経由で停止コマンドを送信しました"
        # RCON 成功時も PID クリーンアップ
        sleep 5
        rm -f "$PID_FILE" 2>/dev/null || true
    fi
}

main "$@"
