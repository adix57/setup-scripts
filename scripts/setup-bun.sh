#!/usr/bin/env bash
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()  { echo -e "${CYAN}[INFO]${NC}  $*"; }
ok()    { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
err()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }

cmd_exists() { command -v "$1" &>/dev/null; }

SETUP_NUM=60
SETUP_NAME="bun"

install_deps() {
    local pkgs=()

    case "$DISTRO" in
        arch)
            for pkg in curl unzip; do
                pacman -Qi "$pkg" &>/dev/null || pkgs+=("$pkg")
            done
            if [ ${#pkgs[@]} -gt 0 ]; then
                sudo pacman -S --needed --noconfirm "${pkgs[@]}"
            fi
            ;;
        debian)
            for pkg in curl unzip; do
                dpkg -s "$pkg" &>/dev/null 2>&1 || pkgs+=("$pkg")
            done
            if [ ${#pkgs[@]} -gt 0 ]; then
                sudo apt-get install -y "${pkgs[@]}"
            fi
            ;;
        fedora)
            for pkg in curl unzip; do
                rpm -q "$pkg" &>/dev/null || pkgs+=("$pkg")
            done
            if [ ${#pkgs[@]} -gt 0 ]; then
                sudo dnf install -y "${pkgs[@]}"
            fi
            ;;
    esac
}

install_bun() {
    if cmd_exists bun; then
        warn "bun already installed, updating..."
        bun upgrade 2>/dev/null || true
    else
        info "Installing bun..."
        curl -fsSL https://bun.sh/install | bash
    fi
    ok "bun installed"
}

ensure_source_block() {
    local rc=$1
    grep -q "# === setup.d ===" "$rc" 2>/dev/null && return
    cat >> "$rc" << 'RC_BLOCK'

# === setup.d ===
for f in "$HOME/.setup.d"/*.sh; do
    [ -f "$f" ] && . "$f"
done
# === end setup.d ===
RC_BLOCK
}

setup_shell() {
    mkdir -p "$HOME/.setup.d"

    cat > "$HOME/.setup.d/${SETUP_NUM}-${SETUP_NAME}.sh" << 'TOOL_BLOCK'
# bun setup
[ -d "$HOME/.bun/bin" ] && export PATH="$HOME/.bun/bin:$PATH"
TOOL_BLOCK

    for sh in $SHELLS; do
        case "$sh" in
            bash)
                ensure_source_block "$HOME/.bashrc"
                ;;
            zsh)
                ensure_source_block "$HOME/.zshrc"
                ;;
            fish)
                mkdir -p "$HOME/.config/fish/conf.d"
                cat > "$HOME/.config/fish/conf.d/${SETUP_NUM}-${SETUP_NAME}.fish" << 'FISH_BLOCK'
# bun setup
if test -d "$HOME/.bun/bin"
    set -gx PATH $HOME/.bun/bin $PATH
end
FISH_BLOCK
                ;;
        esac
    done

    info "Configured ${SETUP_NAME}"
}

uninstall() {
    rm -f "$HOME/.setup.d/${SETUP_NUM}-${SETUP_NAME}.sh"
    rm -f "$HOME/.config/fish/conf.d/${SETUP_NUM}-${SETUP_NAME}.fish"
    rm -rf "$HOME/.bun"
    ok "bun uninstalled"
}

main() {
    if [ "${UNINSTALL:-0}" = "1" ]; then
        uninstall
        exit 0
    fi

    install_deps
    install_bun
    setup_shell

    ok "bun ready! Run: bun create next-app"
}

main "$@"