#!/bin/bash
# =============================================================================
# mc - Minecraft Server Management Script
# Minecraft サーバー管理スクリプト（統合版）
# 
# 使用方法 / Usage:
#   ./mc <command> [options]
#
# コマンド / Commands:
#   setup     - サーバーセットアップ (Paper + Skript ダウンロード)
#   start     - サーバー起動
#   stop      - サーバー停止
#   restart   - サーバー再起動
#   status    - サーバー状態表示
#   logs      - ログ表示
#
# 例 / Examples:
#   ./mc setup                    # 初期セットアップ
#   ./mc start                    # サーバー起動
#   ./mc start --tunnel           # 外部公開付きで起動
#   ./mc stop                     # サーバー停止
#   ./mc status                   # 状態確認
# =============================================================================

set -euo pipefail

# -----------------------------------------------------------------------------
# 定数 / Constants
# -----------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
SERVER_DIR="${PROJECT_ROOT}/minecraft-server"
PID_FILE="${SERVER_DIR}/server.pid"
TUNNEL_PID_FILE="${SERVER_DIR}/tunnel.pid"
TUNNEL_URL_FILE="${SERVER_DIR}/tunnel_url.txt"
JAR_FILE="${SERVER_DIR}/paper.jar"
CONF_FILE="${SERVER_DIR}/start.conf"

# デフォルト設定 / Default Settings
MC_VERSION="1.21.4"
MEMORY_MIN="1G"
MEMORY_MAX="2G"
SERVER_PORT=25566

# カラー / Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

# -----------------------------------------------------------------------------
# ログ関数 / Logging Functions
# -----------------------------------------------------------------------------
log_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
log_tunnel()  { echo -e "${CYAN}[TUNNEL]${NC} $1"; }

# -----------------------------------------------------------------------------
# ヘルプ表示 / Show Help
# -----------------------------------------------------------------------------
show_help() {
    echo ""
    echo -e "${BOLD}Minecraft Server Manager${NC}"
    echo ""
    echo "使用方法: $0 <command> [options]"
    echo ""
    echo -e "${BOLD}コマンド:${NC}"
    echo "  setup     サーバーセットアップ (Paper + Skript)"
    echo "  start     サーバー起動"
    echo "  stop      サーバー停止"
    echo "  restart   サーバー再起動"
    echo "  status    サーバー状態表示"
    echo "  logs      ログ表示 (tail -f)"
    echo ""
    echo -e "${BOLD}オプション (start):${NC}"
    echo "  --tunnel, -t      playit.gg で外部公開"
    echo "  --memory <SIZE>   メモリ設定 (例: 2G, 4G)"
    echo "  --foreground, -f  フォアグラウンドで起動"
    echo ""
    echo -e "${BOLD}オプション (stop):${NC}"
    echo "  --force, -f       強制停止"
    echo ""
    echo -e "${BOLD}例:${NC}"
    echo "  $0 setup"
    echo "  $0 start --tunnel"
    echo "  $0 stop"
    echo ""
}

# -----------------------------------------------------------------------------
# セットアップ / Setup
# -----------------------------------------------------------------------------
cmd_setup() {
    echo ""
    echo "=========================================="
    echo "  Minecraft Paper Server Setup"
    echo "  Target: MC ${MC_VERSION}"
    echo "=========================================="
    echo ""
    
    # 依存関係チェック
    log_info "依存関係をチェック中..."
    for cmd in java curl jq git; do
        if ! command -v "$cmd" &> /dev/null; then
            log_error "$cmd がインストールされていません"
        fi
    done
    log_success "依存関係チェック完了"
    
    # ディレクトリ作成
    log_info "ディレクトリ構造を作成中..."
    mkdir -p "${SERVER_DIR}"/{plugins/Skript/scripts,logs,world}
    log_success "ディレクトリ作成完了"
    
    # Paper ダウンロード
    if [[ ! -f "$JAR_FILE" ]]; then
        log_info "Paper JAR をダウンロード中 (MC ${MC_VERSION})..."
        local api_url="https://api.papermc.io/v2"
        local build_num
        build_num=$(curl -s "${api_url}/projects/paper/versions/${MC_VERSION}/builds" \
            | jq -r '.builds | map(select(.channel == "default")) | last | .build')
        
        if [[ -z "$build_num" || "$build_num" == "null" ]]; then
            log_error "ビルド番号の取得に失敗しました"
        fi
        
        local download_name="paper-${MC_VERSION}-${build_num}.jar"
        local download_url="${api_url}/projects/paper/versions/${MC_VERSION}/builds/${build_num}/downloads/${download_name}"
        
        curl -L -o "$JAR_FILE" "$download_url"
        log_success "Paper ダウンロード完了: ${download_name}"
    else
        log_info "Paper JAR は既に存在します"
    fi
    
    # Skript ダウンロード
    local skript_jar="${SERVER_DIR}/plugins/Skript-*.jar"
    if ! ls $skript_jar 1>/dev/null 2>&1; then
        log_info "Skript プラグインをダウンロード中..."
        local release_info
        release_info=$(curl -s "https://api.github.com/repos/SkriptLang/Skript/releases/latest")
        local skript_url
        skript_url=$(echo "$release_info" | jq -r '.assets[0].browser_download_url')
        local skript_name
        skript_name=$(echo "$release_info" | jq -r '.assets[0].name')
        
        curl -L -o "${SERVER_DIR}/plugins/${skript_name}" "$skript_url"
        log_success "Skript ダウンロード完了: ${skript_name}"
    else
        log_info "Skript は既に存在します"
    fi
    
    # EULA 同意
    echo "eula=true" > "${SERVER_DIR}/eula.txt"
    log_info "eula.txt 作成完了"
    
    # server.properties
    if [[ ! -f "${SERVER_DIR}/server.properties" ]]; then
        cat > "${SERVER_DIR}/server.properties" << EOF
# Minecraft Server Properties (Development)
server-port=${SERVER_PORT}
online-mode=false
enable-rcon=true
rcon.port=25575
rcon.password=dev_rcon_password
motd=\u00a7b[DEV] \u00a7fKrz-Tech Minecraft Server
max-players=10
view-distance=8
simulation-distance=6
EOF
        log_success "server.properties 作成完了"
    fi
    
    echo ""
    log_success "セットアップ完了!"
    echo ""
    echo "次のステップ: $0 start"
    echo ""
}

# -----------------------------------------------------------------------------
# 起動 / Start
# -----------------------------------------------------------------------------
cmd_start() {
    local tunnel=false
    local foreground=false
    
    # 引数パース
    while [[ $# -gt 0 ]]; do
        case $1 in
            --tunnel|-t) tunnel=true; shift ;;
            --foreground|-f) foreground=true; shift ;;
            --memory) MEMORY_MAX="$2"; MEMORY_MIN="$2"; shift 2 ;;
            *) shift ;;
        esac
    done
    
    echo ""
    echo "=========================================="
    echo "  Minecraft Paper Server Launcher"
    echo "=========================================="
    echo ""
    
    # 前提条件チェック
    [[ ! -f "$JAR_FILE" ]] && log_error "paper.jar が見つかりません。先に '$0 setup' を実行してください。"
    [[ ! -f "${SERVER_DIR}/eula.txt" ]] && log_error "eula.txt が見つかりません。先に '$0 setup' を実行してください。"
    
    # 既存プロセスチェック
    check_and_handle_existing_processes
    
    log_info "サーバーを起動中..."
    log_info "メモリ: ${MEMORY_MIN} - ${MEMORY_MAX}"
    log_info "ポート: ${SERVER_PORT}"
    
    cd "$SERVER_DIR"
    
    local aikars_flags="-XX:+UseG1GC -XX:+ParallelRefProcEnabled -XX:MaxGCPauseMillis=200 -XX:+UnlockExperimentalVMOptions -XX:+DisableExplicitGC -XX:+AlwaysPreTouch -XX:G1NewSizePercent=30 -XX:G1MaxNewSizePercent=40 -XX:G1HeapRegionSize=8M -XX:G1ReservePercent=20 -XX:G1HeapWastePercent=5 -XX:G1MixedGCCountTarget=4 -XX:InitiatingHeapOccupancyPercent=15 -XX:G1MixedGCLiveThresholdPercent=90 -XX:G1RSetUpdatingPauseTimePercent=5 -XX:SurvivorRatio=32 -XX:+PerfDisableSharedMem -XX:MaxTenuringThreshold=1"
    
    local java_cmd="java -Xms${MEMORY_MIN} -Xmx${MEMORY_MAX} ${aikars_flags} -jar paper.jar --nogui"
    
    if [[ "$foreground" == true ]]; then
        log_info "フォアグラウンドモードで起動 (Ctrl+C で停止)"
        exec $java_cmd
    else
        nohup $java_cmd > "${SERVER_DIR}/logs/latest.log" 2>&1 &
        local pid=$!
        echo "$pid" > "$PID_FILE"
        
        sleep 3
        if kill -0 "$pid" 2>/dev/null; then
            log_success "サーバー起動成功 (PID: $pid)"
            echo ""
            echo "ログ確認: $0 logs"
            echo "停止:     $0 stop"
            
            if [[ "$tunnel" == true ]]; then
                echo ""
                start_tunnel
            fi
        else
            log_error "サーバー起動失敗。ログを確認してください。"
        fi
    fi
}

# -----------------------------------------------------------------------------
# 既存プロセス処理 / Handle Existing Processes
# -----------------------------------------------------------------------------
check_and_handle_existing_processes() {
    local blocking=()
    local server_pid="" tunnel_pid="" screen_session=""
    
    if [[ -f "$PID_FILE" ]]; then
        server_pid=$(cat "$PID_FILE")
        if kill -0 "$server_pid" 2>/dev/null; then
            blocking+=("Minecraft サーバー (PID: $server_pid)")
        else
            rm -f "$PID_FILE"; server_pid=""
        fi
    fi
    
    if [[ -f "$TUNNEL_PID_FILE" ]]; then
        tunnel_pid=$(cat "$TUNNEL_PID_FILE")
        if kill -0 "$tunnel_pid" 2>/dev/null; then
            blocking+=("playit.gg Tunnel (PID: $tunnel_pid)")
        else
            rm -f "$TUNNEL_PID_FILE"; tunnel_pid=""
        fi
    fi
    
    if screen -ls 2>/dev/null | grep -q playit-tunnel; then
        screen_session="playit-tunnel"
        blocking+=("playit.gg Tunnel (screen)")
    fi
    
    local java_pids
    java_pids=$(pgrep -f "paper.jar" 2>/dev/null || true)
    if [[ -n "$java_pids" && -z "$server_pid" ]]; then
        for jpid in $java_pids; do
            blocking+=("Java プロセス (PID: $jpid)")
        done
    fi
    
    if [[ ${#blocking[@]} -gt 0 ]]; then
        echo -e "${YELLOW}⚠️ 既存プロセスが検出されました:${NC}"
        for proc in "${blocking[@]}"; do
            echo -e "  ${RED}•${NC} $proc"
        done
        echo ""
        echo -e "${BOLD}停止しますか? [y/N]${NC} "
        read -r -t 10 response || response="n"
        
        if [[ "$response" =~ ^[Yy]$ ]]; then
            [[ -n "$screen_session" ]] && screen -S "$screen_session" -X quit 2>/dev/null
            [[ -n "$tunnel_pid" ]] && { kill -15 "$tunnel_pid" 2>/dev/null; sleep 1; kill -9 "$tunnel_pid" 2>/dev/null; rm -f "$TUNNEL_PID_FILE"; }
            [[ -n "$server_pid" ]] && { kill -15 "$server_pid" 2>/dev/null; sleep 2; kill -9 "$server_pid" 2>/dev/null; rm -f "$PID_FILE"; }
            [[ -n "$java_pids" && -z "$server_pid" ]] && { for jpid in $java_pids; do kill -9 "$jpid" 2>/dev/null; done; }
            log_success "既存プロセス停止完了"
        else
            log_error "起動中止。先に '$0 stop' を実行してください。"
        fi
    fi
}

# -----------------------------------------------------------------------------
# トンネル起動 / Start Tunnel
# -----------------------------------------------------------------------------
start_tunnel() {
    log_tunnel "playit.gg Tunnel を起動中..."
    
    local tunnel_log="${SERVER_DIR}/logs/tunnel.log"
    rm -f "$tunnel_log" "$TUNNEL_URL_FILE"
    
    if command -v screen &> /dev/null; then
        screen -dmS playit-tunnel bash -c "playit 2>&1 | tee ${tunnel_log}"
        sleep 2
        local pid
        pid=$(screen -ls | grep playit-tunnel | awk '{print $1}' | cut -d'.' -f1)
        [[ -n "$pid" ]] && echo "$pid" > "$TUNNEL_PID_FILE"
    else
        nohup playit > "$tunnel_log" 2>&1 &
        echo "$!" > "$TUNNEL_PID_FILE"
    fi
    
    # URL 取得
    log_tunnel "接続 URL を取得中..."
    local url=""
    for i in {1..20}; do
        url=$(grep -oE '[a-zA-Z0-9-]+\.(at\.playit\.gg|joinmc\.link)(:[0-9]+)?' "$tunnel_log" 2>/dev/null | head -1 || true)
        [[ -n "$url" ]] && break
        sleep 1
        printf "\r${CYAN}[TUNNEL]${NC} 待機中... %d/20 秒" "$i"
    done
    echo ""
    
    if [[ -n "$url" ]]; then
        echo "$url" > "$TUNNEL_URL_FILE"
        echo ""
        echo -e "${GREEN}${BOLD}=========================================="
        echo "  ✅ 接続アドレス: ${url}"
        echo -e "==========================================${NC}"
        echo ""
    else
        log_warn "URL 自動取得失敗。playit.gg ダッシュボードで確認してください。"
    fi
}

# -----------------------------------------------------------------------------
# 停止 / Stop
# -----------------------------------------------------------------------------
cmd_stop() {
    local force=false
    [[ "${1:-}" == "--force" || "${1:-}" == "-f" ]] && force=true
    
    echo ""
    echo "=========================================="
    echo "  Minecraft Server Shutdown"
    echo "=========================================="
    echo ""
    
    # Tunnel 停止
    if screen -ls 2>/dev/null | grep -q playit-tunnel; then
        screen -S playit-tunnel -X quit 2>/dev/null
        log_tunnel "screen セッション停止"
    fi
    
    if [[ -f "$TUNNEL_PID_FILE" ]]; then
        local tpid
        tpid=$(cat "$TUNNEL_PID_FILE")
        kill -15 "$tpid" 2>/dev/null; sleep 1; kill -9 "$tpid" 2>/dev/null
        rm -f "$TUNNEL_PID_FILE" "$TUNNEL_URL_FILE"
        log_tunnel "Tunnel 停止完了"
    fi
    
    # サーバー停止
    if [[ -f "$PID_FILE" ]]; then
        local pid
        pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            if [[ "$force" == true ]]; then
                log_warn "強制停止 (SIGKILL)..."
                kill -9 "$pid" 2>/dev/null
            else
                log_info "サーバー停止中 (PID: $pid)..."
                kill -15 "$pid" 2>/dev/null
                for i in {1..30}; do
                    kill -0 "$pid" 2>/dev/null || break
                    printf "\r[INFO] 待機中... %d/30 秒" "$i"
                    sleep 1
                done
                echo ""
                kill -9 "$pid" 2>/dev/null || true
            fi
        fi
        rm -f "$PID_FILE"
        log_success "サーバー停止完了"
    else
        log_warn "サーバーは起動していません"
    fi
}

# -----------------------------------------------------------------------------
# ステータス / Status
# -----------------------------------------------------------------------------
cmd_status() {
    echo ""
    echo -e "${BOLD}=========================================="
    echo "  Minecraft Server Status"
    echo -e "==========================================${NC}"
    echo ""
    
    # サーバー状態
    echo -e "${BOLD}[Server]${NC}"
    if [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
        echo -e "  Status: ${GREEN}● Running${NC} (PID: $(cat "$PID_FILE"))"
    else
        echo -e "  Status: ${YELLOW}○ Stopped${NC}"
    fi
    
    # Tunnel 状態
    echo ""
    echo -e "${BOLD}[Tunnel]${NC}"
    if screen -ls 2>/dev/null | grep -q playit-tunnel || { [[ -f "$TUNNEL_PID_FILE" ]] && kill -0 "$(cat "$TUNNEL_PID_FILE")" 2>/dev/null; }; then
        echo -e "  Status: ${GREEN}● Running${NC}"
        if [[ -f "$TUNNEL_URL_FILE" ]]; then
            echo -e "  URL:    ${GREEN}${BOLD}$(cat "$TUNNEL_URL_FILE")${NC}"
        fi
    else
        echo -e "  Status: ${YELLOW}○ Stopped${NC}"
    fi
    
    echo ""
    echo -e "${BOLD}[Commands]${NC}"
    echo "  $0 start [--tunnel]"
    echo "  $0 stop"
    echo "  $0 logs"
    echo ""
}

# -----------------------------------------------------------------------------
# ログ表示 / Logs
# -----------------------------------------------------------------------------
cmd_logs() {
    local log_file="${SERVER_DIR}/logs/latest.log"
    if [[ -f "$log_file" ]]; then
        tail -f "$log_file"
    else
        log_error "ログファイルが見つかりません"
    fi
}

# -----------------------------------------------------------------------------
# メイン / Main
# -----------------------------------------------------------------------------
main() {
    local command="${1:-}"
    shift || true
    
    case "$command" in
        setup)   cmd_setup "$@" ;;
        start)   cmd_start "$@" ;;
        stop)    cmd_stop "$@" ;;
        restart) cmd_stop "$@"; sleep 2; cmd_start "$@" ;;
        status)  cmd_status "$@" ;;
        logs)    cmd_logs "$@" ;;
        -h|--help|help|"") show_help ;;
        *) log_error "不明なコマンド: $command (use '$0 --help')" ;;
    esac
}

main "$@"
