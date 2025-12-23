#!/bin/bash
# =============================================================================
# mc - Minecraft Server Management Script
# 
# 使用方法: ./mc <command>
#
# コマンド:
#   setup   - サーバーセットアップ + Coder ログイン
#   start   - サーバー + ポートフォワード起動
#   stop    - 全停止
#   restart - 再起動
#   status  - 状態確認
#   logs    - サーバーログ
#   attach  - screen セッションに接続
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
SERVER_DIR="${PROJECT_ROOT}/minecraft-server"
JAR_FILE="${SERVER_DIR}/paper.jar"

# Screen セッション名
SCREEN_SERVER="mc-server"
SCREEN_TUNNEL="mc-tunnel"

# 設定
MC_VERSION="1.21.4"
SERVER_PORT=25566
LOCAL_PORT=25565
MEMORY="2G"
CODER_URL="https://coder.krz-tech.net"

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
    for cmd in java curl jq screen; do
        command -v "$cmd" &>/dev/null || log_error "$cmd が必要です"
    done
    
    # Coder CLI ログイン
    log_info "Coder CLI ログイン中..."
    coder login "$CODER_URL" || log_warn "Coder ログインをスキップ (既にログイン済みの可能性)"
    log_success "Coder CLI 準備完了"
    
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
    else
        log_info "Paper は既に存在します"
    fi
    
    # Skript ダウンロード
    if ! ls "${SERVER_DIR}"/plugins/Skript-*.jar 1>/dev/null 2>&1; then
        log_info "Skript をダウンロード中..."
        local url
        url=$(curl -s "https://api.github.com/repos/SkriptLang/Skript/releases/latest" | jq -r '.assets[0].browser_download_url')
        curl -sL -o "${SERVER_DIR}/plugins/$(basename "$url")" "$url"
        log_success "Skript"
    else
        log_info "Skript は既に存在します"
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
        log_success "server.properties 作成"
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
    
    # 既存セッション確認
    if screen -ls | grep -q "$SCREEN_SERVER"; then
        log_warn "サーバーは既に起動中です"
        echo -e "状態確認: ${CYAN}./mc status${NC}"
        echo -e "停止:     ${CYAN}./mc stop${NC}"
        exit 0
    fi
    
    # Minecraft サーバー起動 (screen)
    log_info "Minecraft サーバーを起動中..."
    local flags="-XX:+UseG1GC -XX:+ParallelRefProcEnabled -XX:MaxGCPauseMillis=200"
    screen -dmS "$SCREEN_SERVER" bash -c "cd ${SERVER_DIR} && java -Xms${MEMORY} -Xmx${MEMORY} ${flags} -jar paper.jar --nogui 2>&1 | tee logs/latest.log"
    sleep 2
    
    if screen -ls | grep -q "$SCREEN_SERVER"; then
        log_success "サーバー起動成功 (screen: $SCREEN_SERVER)"
    else
        log_error "サーバー起動失敗"
    fi
    
    # Coder ポートフォワード起動 (screen)
    log_info "ポートフォワードを起動中..."
    local workspace_name
    workspace_name=$(hostname)
    screen -dmS "$SCREEN_TUNNEL" bash -c "coder port-forward ${workspace_name} --tcp ${LOCAL_PORT}:${SERVER_PORT} 2>&1"
    sleep 2
    
    if screen -ls | grep -q "$SCREEN_TUNNEL"; then
        log_success "ポートフォワード起動成功 (screen: $SCREEN_TUNNEL)"
    else
        log_warn "ポートフォワード起動失敗"
    fi
    
    # 接続情報表示
    echo ""
    echo -e "${BOLD}${CYAN}=========================================="
    echo "  ✅ Minecraft サーバー起動完了"
    echo -e "==========================================${NC}"
    echo ""
    echo -e "  接続先: ${GREEN}${BOLD}localhost:${LOCAL_PORT}${NC}"
    echo ""
    echo -e "  screen 接続:"
    echo -e "    サーバー:  ${CYAN}screen -r ${SCREEN_SERVER}${NC}"
    echo -e "    トンネル:  ${CYAN}screen -r ${SCREEN_TUNNEL}${NC}"
    echo ""
    echo -e "${CYAN}==========================================${NC}"
    echo ""
}

# -----------------------------------------------------------------------------
# 停止
# -----------------------------------------------------------------------------
cmd_stop() {
    echo ""
    echo -e "${BOLD}=== Minecraft Server Stop ===${NC}"
    echo ""
    
    # トンネル停止
    if screen -ls | grep -q "$SCREEN_TUNNEL"; then
        log_info "ポートフォワードを停止中..."
        screen -S "$SCREEN_TUNNEL" -X quit 2>/dev/null || true
        log_success "ポートフォワード停止"
    fi
    
    # サーバー停止
    if screen -ls | grep -q "$SCREEN_SERVER"; then
        log_info "サーバーを停止中..."
        # stop コマンドを送信
        screen -S "$SCREEN_SERVER" -p 0 -X stuff "stop$(printf '\r')"
        sleep 5
        # まだ動いていれば強制終了
        if screen -ls | grep -q "$SCREEN_SERVER"; then
            screen -S "$SCREEN_SERVER" -X quit 2>/dev/null || true
        fi
        log_success "サーバー停止"
    else
        log_warn "サーバーは起動していません"
    fi
    
    echo ""
}

# -----------------------------------------------------------------------------
# ステータス
# -----------------------------------------------------------------------------
cmd_status() {
    echo ""
    echo -e "${BOLD}=== Minecraft Server Status ===${NC}"
    echo ""
    
    # サーバー
    if screen -ls | grep -q "$SCREEN_SERVER"; then
        echo -e "  Server:  ${GREEN}● Running${NC} (screen: $SCREEN_SERVER)"
    else
        echo -e "  Server:  ${YELLOW}○ Stopped${NC}"
    fi
    
    # トンネル
    if screen -ls | grep -q "$SCREEN_TUNNEL"; then
        echo -e "  Tunnel:  ${GREEN}● Running${NC} (screen: $SCREEN_TUNNEL)"
        echo -e "  接続先:  ${GREEN}localhost:${LOCAL_PORT}${NC}"
    else
        echo -e "  Tunnel:  ${YELLOW}○ Stopped${NC}"
    fi
    
    echo ""
    echo -e "  操作:"
    echo -e "    起動: ${CYAN}./mc start${NC}"
    echo -e "    停止: ${CYAN}./mc stop${NC}"
    echo -e "    接続: ${CYAN}screen -r ${SCREEN_SERVER}${NC}"
    echo ""
}

# -----------------------------------------------------------------------------
# ログ
# -----------------------------------------------------------------------------
cmd_logs() {
    local log="${SERVER_DIR}/logs/latest.log"
    if [[ -f "$log" ]]; then
        tail -f "$log"
    else
        log_error "ログが見つかりません"
    fi
}

# -----------------------------------------------------------------------------
# Screen 接続
# -----------------------------------------------------------------------------
cmd_attach() {
    local target="${1:-server}"
    case "$target" in
        server|s) screen -r "$SCREEN_SERVER" ;;
        tunnel|t) screen -r "$SCREEN_TUNNEL" ;;
        *) echo "使用方法: ./mc attach [server|tunnel]" ;;
    esac
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
    echo "  setup        セットアップ + Coder ログイン"
    echo "  start        サーバー + トンネル起動"
    echo "  stop         全停止"
    echo "  restart      再起動"
    echo "  status       状態確認"
    echo "  logs         サーバーログ"
    echo "  attach [s|t] screen 接続 (server/tunnel)"
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
    attach)  cmd_attach "${2:-}" ;;
    *)       show_help ;;
esac
