#!/bin/bash
# =============================================================================
# mc - Minecraft Server Management Script
# 
# 使用方法: ./mc <command>
#
# コマンド:
#   setup   - サーバーセットアップ (Paper + Skript)
#   start   - サーバー起動
#   stop    - サーバー停止
#   restart - 再起動
#   status  - 状態表示
#   logs    - ログ表示
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
SERVER_DIR="${PROJECT_ROOT}/minecraft-server"
PID_FILE="${SERVER_DIR}/server.pid"
JAR_FILE="${SERVER_DIR}/paper.jar"

MC_VERSION="1.21.4"
SERVER_PORT=25566
MEMORY="2G"

# カラー
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

log_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# -----------------------------------------------------------------------------
# セットアップ
# -----------------------------------------------------------------------------
cmd_setup() {
    echo ""
    echo -e "${BOLD}=== Minecraft Server Setup ===${NC}"
    echo ""
    
    # 依存チェック
    for cmd in java curl jq; do
        command -v "$cmd" &>/dev/null || log_error "$cmd が必要です"
    done
    
    mkdir -p "${SERVER_DIR}"/{plugins/Skript/scripts,logs}
    
    # Paper ダウンロード
    if [[ ! -f "$JAR_FILE" ]]; then
        log_info "Paper をダウンロード中..."
        local api="https://api.papermc.io/v2"
        local build
        build=$(curl -s "${api}/projects/paper/versions/${MC_VERSION}/builds" \
            | jq -r '.builds | map(select(.channel == "default")) | last | .build')
        curl -sL -o "$JAR_FILE" "${api}/projects/paper/versions/${MC_VERSION}/builds/${build}/downloads/paper-${MC_VERSION}-${build}.jar"
        log_success "Paper ${MC_VERSION}-${build}"
    fi
    
    # Skript ダウンロード
    if ! ls "${SERVER_DIR}"/plugins/Skript-*.jar 1>/dev/null 2>&1; then
        log_info "Skript をダウンロード中..."
        local url
        url=$(curl -s "https://api.github.com/repos/SkriptLang/Skript/releases/latest" | jq -r '.assets[0].browser_download_url')
        curl -sL -o "${SERVER_DIR}/plugins/$(basename "$url")" "$url"
        log_success "Skript"
    fi
    
    # 設定ファイル
    echo "eula=true" > "${SERVER_DIR}/eula.txt"
    
    if [[ ! -f "${SERVER_DIR}/server.properties" ]]; then
        cat > "${SERVER_DIR}/server.properties" << EOF
server-port=${SERVER_PORT}
online-mode=false
motd=\u00a7b[DEV] \u00a7fMinecraft Development Server
max-players=10
EOF
    fi
    
    echo ""
    log_success "セットアップ完了"
    echo ""
    echo "次: ./mc start"
    echo ""
}

# -----------------------------------------------------------------------------
# 起動
# -----------------------------------------------------------------------------
cmd_start() {
    echo ""
    echo -e "${BOLD}=== Minecraft Server Start ===${NC}"
    echo ""
    
    [[ ! -f "$JAR_FILE" ]] && log_error "先に ./mc setup を実行してください"
    
    # 既存プロセス確認
    if [[ -f "$PID_FILE" ]]; then
        local pid
        pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            log_warn "既に起動中 (PID: $pid)"
            echo -e "停止: ${CYAN}./mc stop${NC}"
            exit 0
        fi
        rm -f "$PID_FILE"
    fi
    
    log_info "サーバー起動中..."
    cd "$SERVER_DIR"
    
    local flags="-XX:+UseG1GC -XX:+ParallelRefProcEnabled -XX:MaxGCPauseMillis=200"
    nohup java -Xms${MEMORY} -Xmx${MEMORY} ${flags} -jar paper.jar --nogui > logs/latest.log 2>&1 &
    echo "$!" > "$PID_FILE"
    
    sleep 2
    if kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
        log_success "起動成功 (PID: $(cat "$PID_FILE"))"
    else
        log_error "起動失敗"
    fi
    
    # 接続方法表示
    echo ""
    echo -e "${BOLD}${CYAN}=========================================="
    echo "  接続方法"
    echo -e "==========================================${NC}"
    echo ""
    echo "  ローカルマシンで以下を実行:"
    echo ""
    echo -e "  ${GREEN}coder port-forward \$(hostname) --tcp 25565:${SERVER_PORT}${NC}"
    echo ""
    echo "  その後 Minecraft で localhost:25565 に接続"
    echo ""
    echo -e "${CYAN}==========================================${NC}"
    echo ""
    echo -e "ログ: ${CYAN}./mc logs${NC}"
    echo -e "停止: ${CYAN}./mc stop${NC}"
    echo ""
}

# -----------------------------------------------------------------------------
# 停止
# -----------------------------------------------------------------------------
cmd_stop() {
    echo ""
    echo -e "${BOLD}=== Minecraft Server Stop ===${NC}"
    echo ""
    
    if [[ ! -f "$PID_FILE" ]]; then
        log_warn "サーバーは起動していません"
        return
    fi
    
    local pid
    pid=$(cat "$PID_FILE")
    
    if kill -0 "$pid" 2>/dev/null; then
        log_info "停止中 (PID: $pid)..."
        kill -15 "$pid"
        for i in {1..15}; do
            kill -0 "$pid" 2>/dev/null || break
            sleep 1
        done
        kill -9 "$pid" 2>/dev/null || true
    fi
    
    rm -f "$PID_FILE"
    log_success "停止完了"
    echo ""
}

# -----------------------------------------------------------------------------
# ステータス
# -----------------------------------------------------------------------------
cmd_status() {
    echo ""
    echo -e "${BOLD}=== Minecraft Server Status ===${NC}"
    echo ""
    
    if [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
        echo -e "  Server: ${GREEN}● Running${NC} (PID: $(cat "$PID_FILE"))"
        echo -e "  Port:   ${SERVER_PORT}"
        echo ""
        echo -e "  接続: ${CYAN}coder port-forward \$(hostname) --tcp 25565:${SERVER_PORT}${NC}"
    else
        echo -e "  Server: ${YELLOW}○ Stopped${NC}"
    fi
    echo ""
}

# -----------------------------------------------------------------------------
# ログ
# -----------------------------------------------------------------------------
cmd_logs() {
    local log="${SERVER_DIR}/logs/latest.log"
    [[ -f "$log" ]] && tail -f "$log" || log_error "ログなし"
}

# -----------------------------------------------------------------------------
# ヘルプ
# -----------------------------------------------------------------------------
show_help() {
    echo ""
    echo -e "${BOLD}Minecraft Server Manager${NC}"
    echo ""
    echo "使用方法: ./mc <command>"
    echo ""
    echo "  setup   セットアップ"
    echo "  start   起動"
    echo "  stop    停止"
    echo "  restart 再起動"
    echo "  status  状態"
    echo "  logs    ログ"
    echo ""
}

# -----------------------------------------------------------------------------
# メイン
# -----------------------------------------------------------------------------
case "${1:-}" in
    setup)   cmd_setup ;;
    start)   cmd_start ;;
    stop)    cmd_stop ;;
    restart) cmd_stop; sleep 1; cmd_start ;;
    status)  cmd_status ;;
    logs)    cmd_logs ;;
    *)       show_help ;;
esac
