#!/bin/bash
# =============================================================================
# status-minecraft-server.sh
# Minecraft サーバー状態表示スクリプト
# 
# 使用方法 / Usage:
#   ./scripts/status-minecraft-server.sh
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

# -----------------------------------------------------------------------------
# カラー出力 / Colored Output
# -----------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# -----------------------------------------------------------------------------
# メイン / Main
# -----------------------------------------------------------------------------
main() {
    echo ""
    echo -e "${BOLD}=========================================="
    echo "  Minecraft Server Status"
    echo -e "==========================================${NC}"
    echo ""
    
    # サーバー状態
    echo -e "${BOLD}[Server]${NC}"
    if [[ -f "$PID_FILE" ]]; then
        local pid
        pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            echo -e "  Status: ${GREEN}● Running${NC} (PID: $pid)"
            
            # ポート確認
            local port=25566
            if [[ -f "${SERVER_DIR}/server.properties" ]]; then
                port=$(grep "^server-port=" "${SERVER_DIR}/server.properties" | cut -d'=' -f2 | tr -d '\r' || echo "25566")
            fi
            echo -e "  Port:   ${CYAN}${port}${NC}"
        else
            echo -e "  Status: ${RED}● Stopped${NC} (stale PID file)"
        fi
    else
        echo -e "  Status: ${YELLOW}○ Not running${NC}"
    fi
    
    echo ""
    
    # トンネル状態
    echo -e "${BOLD}[Tunnel]${NC}"
    local tunnel_running=false
    
    # screen セッション確認
    if screen -ls 2>/dev/null | grep -q playit-tunnel; then
        tunnel_running=true
        echo -e "  Status: ${GREEN}● Running${NC} (screen: playit-tunnel)"
    elif [[ -f "$TUNNEL_PID_FILE" ]]; then
        local tunnel_pid
        tunnel_pid=$(cat "$TUNNEL_PID_FILE")
        if kill -0 "$tunnel_pid" 2>/dev/null; then
            tunnel_running=true
            echo -e "  Status: ${GREEN}● Running${NC} (PID: $tunnel_pid)"
        else
            echo -e "  Status: ${YELLOW}○ Not running${NC}"
        fi
    else
        echo -e "  Status: ${YELLOW}○ Not running${NC}"
    fi
    
    # playit.gg 接続情報
    if [[ "$tunnel_running" == true ]]; then
        echo ""
        echo -e "${BOLD}[Connection URL]${NC}"
        
        # 保存されたURLがあれば表示
        if [[ -f "${SERVER_DIR}/tunnel_url.txt" ]]; then
            local url
            url=$(cat "${SERVER_DIR}/tunnel_url.txt")
            echo -e "  ${GREEN}${BOLD}${url}${NC}"
            echo ""
            echo "  ↑ 上記アドレスで Minecraft から接続できます"
        else
            echo -e "  URL: ${YELLOW}取得中...または未設定${NC}"
            echo ""
            echo "  playit.gg ダッシュボードで確認:"
            echo -e "  ${CYAN}https://playit.gg/account/tunnels${NC}"
        fi
    fi
    
    echo ""
    echo -e "${BOLD}[Commands]${NC}"
    echo "  起動:   ./scripts/start-minecraft-server.sh"
    echo "  停止:   ./scripts/stop-minecraft-server.sh"
    echo "  外部公開: ./scripts/start-minecraft-server.sh --tunnel"
    echo "  ログ:   tail -f minecraft-server/logs/latest.log"
    echo ""
}

main "$@"
