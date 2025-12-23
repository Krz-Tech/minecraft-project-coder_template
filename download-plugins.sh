#!/bin/bash
# =============================================================================
# download-plugins.sh - 開発サーバー用プラグイン一括ダウンロード
# 
# 使用方法: ./download-plugins.sh [output_dir]
# デフォルト出力先: ./minecraft-server/plugins/
# =============================================================================

set -euo pipefail

# 出力ディレクトリ
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="${1:-${SCRIPT_DIR}/minecraft-server/plugins}"

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
log_error()   { echo -e "${RED}[ERROR]${NC} $1"; }

# -----------------------------------------------------------------------------
# GitHub Latest Release からダウンロード
# -----------------------------------------------------------------------------
download_github_release() {
    local repo="$1"
    local name="$2"
    local filter="${3:-.jar}"
    
    log_info "${name} をダウンロード中... (${repo})"
    
    local url
    url=$(curl -sL "https://api.github.com/repos/${repo}/releases/latest" \
        | jq -r ".assets[] | select(.name | endswith(\"${filter}\")) | .browser_download_url" \
        | head -1)
    
    if [[ -z "$url" || "$url" == "null" ]]; then
        log_warn "${name}: ダウンロードURLが見つかりません"
        return 1
    fi
    
    local filename
    filename=$(basename "$url")
    
    # 既存ファイルをチェック（バージョン違いも含む）
    local existing
    existing=$(ls "${OUTPUT_DIR}"/${name}*.jar 2>/dev/null | head -1 || true)
    if [[ -n "$existing" ]]; then
        log_warn "${name}: 既存ファイルあり ($(basename "$existing"))"
        return 0
    fi
    
    curl -sL -o "${OUTPUT_DIR}/${filename}" "$url"
    log_success "${name} -> ${filename}"
}

# -----------------------------------------------------------------------------
# Modrinth からダウンロード (タイムアウト付き)
# -----------------------------------------------------------------------------
download_modrinth() {
    local project="$1"
    local name="$2"
    local loader="${3:-paper}"
    
    log_info "${name} をダウンロード中... (Modrinth: ${project})"
    
    # 既存ファイルをチェック
    if ls "${OUTPUT_DIR}"/${name}*.jar 2>/dev/null | head -1 > /dev/null; then
        log_warn "${name}: 既存ファイルあり"
        return 0
    fi
    
    # 最新バージョンを取得 (10秒タイムアウト)
    local version_data
    version_data=$(curl -sL --connect-timeout 10 --max-time 15 \
        "https://api.modrinth.com/v2/project/${project}/version?loaders=[\"${loader}\"]&limit=1" 2>/dev/null || echo "")
    
    if [[ -z "$version_data" || "$version_data" == "[]" ]]; then
        log_warn "${name}: Modrinth APIからの応答なし"
        return 1
    fi
    
    local url
    url=$(echo "$version_data" | jq -r '.[0].files[0].url // empty' 2>/dev/null || echo "")
    
    if [[ -z "$url" ]]; then
        log_warn "${name}: ダウンロードURLが見つかりません"
        return 1
    fi
    
    local filename
    filename=$(echo "$version_data" | jq -r '.[0].files[0].filename // empty')
    
    if [[ -z "$filename" ]]; then
        filename="${name}.jar"
    fi
    
    curl -sL --connect-timeout 10 --max-time 60 -o "${OUTPUT_DIR}/${filename}" "$url"
    log_success "${name} -> ${filename}"
}


# -----------------------------------------------------------------------------
# Jenkins からダウンロード (LuckPerms)
# -----------------------------------------------------------------------------
download_luckperms() {
    log_info "LuckPerms をダウンロード中..."
    
    local url="https://download.luckperms.net/1568/bukkit/loader/LuckPerms-Bukkit-5.4.156.jar"
    local filename="LuckPerms-Bukkit-5.4.156.jar"
    
    # 既存ファイルをチェック
    if ls "${OUTPUT_DIR}"/LuckPerms*.jar 2>/dev/null | head -1 > /dev/null; then
        log_warn "LuckPerms: 既存ファイルあり"
        return 0
    fi
    
    # 最新版を取得（APIから）
    local latest_url
    latest_url=$(curl -sL "https://metadata.luckperms.net/data/all" | jq -r '.downloads.bukkit // empty')
    
    if [[ -n "$latest_url" ]]; then
        filename=$(basename "$latest_url")
        curl -sL -o "${OUTPUT_DIR}/${filename}" "$latest_url"
    else
        curl -sL -o "${OUTPUT_DIR}/${filename}" "$url"
    fi
    
    log_success "LuckPerms -> ${filename}"
}

# -----------------------------------------------------------------------------
# Vault (GitHub)
# -----------------------------------------------------------------------------
download_vault() {
    log_info "Vault をダウンロード中..."
    
    if ls "${OUTPUT_DIR}"/Vault*.jar 2>/dev/null | head -1 > /dev/null; then
        log_warn "Vault: 既存ファイルあり"
        return 0
    fi
    
    local url
    url=$(curl -sL "https://api.github.com/repos/MilkBowl/Vault/releases/latest" \
        | jq -r '.assets[0].browser_download_url')
    
    local filename
    filename=$(basename "$url")
    curl -sL -o "${OUTPUT_DIR}/${filename}" "$url"
    log_success "Vault -> ${filename}"
}

# -----------------------------------------------------------------------------
# PlaceholderAPI (eCloud/GitHub)
# -----------------------------------------------------------------------------
download_placeholderapi() {
    log_info "PlaceholderAPI をダウンロード中..."
    
    if ls "${OUTPUT_DIR}"/PlaceholderAPI*.jar 2>/dev/null | head -1 > /dev/null; then
        log_warn "PlaceholderAPI: 既存ファイルあり"
        return 0
    fi
    
    local url
    url=$(curl -sL "https://api.github.com/repos/PlaceholderAPI/PlaceholderAPI/releases/latest" \
        | jq -r '.assets[] | select(.name | endswith(".jar")) | .browser_download_url' \
        | head -1)
    
    local filename
    filename=$(basename "$url")
    curl -sL -o "${OUTPUT_DIR}/${filename}" "$url"
    log_success "PlaceholderAPI -> ${filename}"
}

# -----------------------------------------------------------------------------
# メイン
# -----------------------------------------------------------------------------
main() {
    echo ""
    echo -e "${BOLD}=== Minecraft Plugin Downloader ===${NC}"
    echo ""
    echo -e "出力先: ${CYAN}${OUTPUT_DIR}${NC}"
    echo ""
    
    # 依存チェック
    for cmd in curl jq; do
        command -v "$cmd" &>/dev/null || { log_error "$cmd が必要です"; exit 1; }
    done
    
    # 出力ディレクトリ作成
    mkdir -p "${OUTPUT_DIR}"
    mkdir -p "${OUTPUT_DIR}/Skript/scripts"
    
    echo -e "${BOLD}--- 基盤プラグイン ---${NC}"
    
    # Skript
    download_github_release "SkriptLang/Skript" "Skript" ".jar"
    
    # SkBee (Modrinth -> GitHub fallback)
    download_modrinth "skbee" "SkBee" "paper" || \
        download_github_release "ShaneBeee/SkBee" "SkBee" ".jar"
    
    # skript-reflect
    download_github_release "SkriptLang/skript-reflect" "skript-reflect" ".jar"
    
    # SkQuery (Modrinth -> GitHub fallback)
    download_modrinth "skquery" "SkQuery" "paper" || \
        download_github_release "SkQuery/SkQuery" "SkQuery" ".jar"
    
    # Vault
    download_vault
    
    # LuckPerms
    download_luckperms
    
    # PlaceholderAPI
    download_placeholderapi
    
    echo ""
    echo -e "${BOLD}--- サードパーティプラグイン ---${NC}"
    
    # DiscordSRV
    download_github_release "DiscordSRV/DiscordSRV" "DiscordSRV" ".jar"
    
    # BlueMap (Modrinth -> GitHub fallback)
    download_modrinth "bluemap" "BlueMap" "paper" || \
        download_github_release "BlueMap-Minecraft/BlueMap" "BlueMap" ".jar"
    
    echo ""
    echo -e "${BOLD}${GREEN}=== ダウンロード完了 ===${NC}"
    echo ""
    echo "ダウンロードされたプラグイン:"
    ls -la "${OUTPUT_DIR}"/*.jar 2>/dev/null || echo "  (なし)"
    echo ""
}

main "$@"
