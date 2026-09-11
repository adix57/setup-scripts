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

SETUP_NUM=40
SETUP_NAME="anaconda"

install_deps() {
    local pkgs=()

    case "$DISTRO" in
        arch)
            for pkg in curl; do
                pacman -Qi "$pkg" &>/dev/null || pkgs+=("$pkg")
            done
            if [ ${#pkgs[@]} -gt 0 ]; then
                sudo pacman -S --needed --noconfirm "${pkgs[@]}"
            fi
            ;;
        debian)
            for pkg in curl; do
                dpkg -s "$pkg" &>/dev/null 2>&1 || pkgs+=("$pkg")
            done
            if [ ${#pkgs[@]} -gt 0 ]; then
                sudo apt-get install -y "${pkgs[@]}"
            fi
            ;;
        fedora)
            for pkg in curl; do
                rpm -q "$pkg" &>/dev/null || pkgs+=("$pkg")
            done
            if [ ${#pkgs[@]} -gt 0 ]; then
                sudo dnf install -y "${pkgs[@]}"
            fi
            ;;
    esac
}

install_anaconda() {
    if cmd_exists conda || [ -d "$HOME/.anaconda3" ]; then
        warn "anaconda already installed, skipping..."
        return
    fi

    local arch
    arch=$(uname -m)
    case "$arch" in
        x86_64)  arch="x86_64" ;;
        aarch64) arch="aarch64" ;;
        *) err "Unsupported architecture: $arch"; exit 1 ;;
    esac

    info "Fetching latest Anaconda version..."
    local file
    file=$(curl -fsSL https://repo.anaconda.com/archive/ | grep -oE "Anaconda3-[0-9]{4}\.[0-9]{2}(-[0-9]+)?-Linux-${arch}\.sh" | sort -V | tail -1)

    if [ -z "$file" ]; then
        warn "Could not resolve latest version, using fallback..."
        file="Anaconda3-2024.10-1-Linux-${arch}.sh"
    fi

    info "Installing $file..."
    curl -fsSL "https://repo.anaconda.com/archive/$file" -o /tmp/anaconda.sh
    bash /tmp/anaconda.sh -b -p "$HOME/.anaconda3"
    rm -f /tmp/anaconda.sh

    info "Disabling auto-activation of base env..."
    "$HOME/.anaconda3/bin/conda" config --set auto_activate_base false
    ok "anaconda installed"
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
# anaconda setup
if [ -d "$HOME/.anaconda3" ]; then
    source "$HOME/.anaconda3/etc/profile.d/conda.sh"
    export PATH="$HOME/.anaconda3/bin:$PATH"
fi
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
# anaconda setup
if test -d "$HOME/.anaconda3"
    set -gx PATH $HOME/.anaconda3/bin $PATH
    source "$HOME/.anaconda3/etc/fish/conf.d/conda.fish"
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
    rm -rf "$HOME/.anaconda3"
    ok "anaconda uninstalled"
}

main() {
    if [ "${UNINSTALL:-0}" = "1" ]; then
        uninstall
        exit 0
    fi

    install_deps
    install_anaconda
    setup_shell

    ok "anaconda ready! Run: conda create -n myenv python=3.12 && conda activate myenv"
}

main "$@"